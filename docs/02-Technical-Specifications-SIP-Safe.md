# Technical Specifications
## Custom Space Name Tool for macOS - SIP-Safe Edition

**Version:** 1.0  
**Date:** 2026-08-08  
**Status:** Draft for build

### 1. Overall Architecture

Single user-facing app, no plugin, no helper daemon, no injection.

```
[App Process - com.example.SpaceNameTool]
  ├─ MenuBarController (shows current Space name)
  ├─ SpaceMonitor (detects Spaces and switches)
  ├─ NameStore (plist + JSON backup)
  ├─ OverlayWindowController (Heads-Up bezel)
  └─ SwitcherWindowController (custom switcher palette)
```

Runs as regular user app with hardened runtime. No root.

### 2. Name Storage - Robust Keying

The core problem of all Space renamers: Space indices shift.

**Storage location:** 
`~/Library/Application Support/SpaceNameTool/names.plist` + `names.json` for export.
Sandbox-compatible if App Store build: `~/Library/Containers/com.example.SpaceNameTool/Data/Library/...`

**Data model:**

```swift
struct DisplayID: Codable, Hashable {
  let cgDirectDisplayID: UInt32 // from CGDisplay, stable per display
  let uuidString: String? // from CGDisplayCreateUUIDFromDisplayID, best effort
  let localizedName: String // fallback: "DELL U2723DE"
}

struct SpaceRecord: Codable {
  let persistentID: String // our own UUID, assigned on first seen
  let managedSpaceID: UInt64? // from CGSCopyManagedDisplaySpaces -> "ManagedSpaceID" or "SpaceID" if present
  let display: DisplayID
  let creationOrder: Int // monotonic counter to detect re-order
  var customName: String
  var lastSeenIndex: Int
  var lastSeenAt: Date
}
```

**Keying strategy (in order of preference):**

1. If `ManagedSpaceID` exists in `CGSCopyManagedDisplaySpaces`, use it as stable key. On Tahoe this field still exists but is undocumented - verify at launch.
2. Else, use combination of `display.uuidString + creationOrder`. creationOrder is assigned when we first see a Space and never reused.
3. Never key solely by array index. On add/remove, diff current topology against stored records by managedSpaceID first, then by display + relative order + heuristic (neighbor preservation).

**Diff algorithm on topology change:**

1. Fetch `spaces = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())`
2. Flatten to list per display.
3. Match each live space to stored record by managedSpaceID. 
4. Unmatched live spaces = new Spaces -> assign new persistentID.
5. Unmatched stored records that haven't been seen for >7 days -> move to archive, don't delete immediately.
6. Present UI: "We detected new Space, name it?"

This solves FR-6 without data loss.

### 3. Detection of Spaces - SIP-Safe Reading

Reading private CGS does NOT require SIP disabled. Only writing/injecting does.

Approved calls (all read-only):

- `CGSMainConnectionID()` -> `int`
- `CGSCopyManagedDisplaySpaces(_:)` -> CFArray of displays, each with "Spaces" array
- `CGSGetActiveSpace(_:)` -> active space ID
- `CGSCopyActiveMenuBarDisplayIdentifier` / `CGDisplayCreateUUIDFromDisplayID` for display stable ID

**Implementation detail:** Dynamically load via `dlsym` from `/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight` to avoid link-time hard dependency. If Apple removes symbols, degrade gracefully to index-only mode and warn user.

**Space switch detection - no polling:**

- Observe `NSWorkspace.shared.notificationCenter` -> `NSWorkspace.activeSpaceDidChangeNotification` (available since macOS 13)
- Fallback: `NSDistributedNotificationCenter` for `com.apple.spaces.switch`
- Last resort: 1Hz timer calling `CGSGetActiveSpace` - cheap, but only if notifications fail.

This meets NFR-3 (<1% CPU).

### 4. UI

#### 4.1 Menu Bar

- `NSStatusItem` with variable length
- Shows icon + truncated custom name: "▣ Terminal" or "2: Terminal" if user prefers
- Click -> popover lists all Spaces per display with custom names, current highlighted
- Right-click -> Preferences, Reset, Quit

#### 4.2 Configuration Window

SwiftUI window:
- Left sidebar: Displays
- Right: List of Spaces on that display, each row: [Preview thumbnail placeholder] [Index] [TextField: custom name] 
- Live update to NameStore on edit, debounced 200ms.

#### 4.3 Heads-Up Overlay (FR-3)

- `NSPanel` with style `.nonactivatingPanel`, level `.screenSaver - 1`, `isFloatingPanel = true`, `ignoresMouseEvents = true`
- Center of active screen, auto-dismiss after 1.5s with fade
- Uses `NSVisualEffectView` for system look.
- Triggered by SpaceMonitor when active space changes.

#### 4.4 Custom Switcher (FR-4)

- Hotkey registered via `MASShortcut` or `KeyboardShortcuts` (no private APIs, no EventTap requiring Accessibility if possible; if EventTap needed, request Accessibility with clear prompt)
- Window: Spotlight-like search. Type to filter Space names. Arrow keys + Enter to jump.
- Jumping implementation (SIP-safe, in order of attempt):
  1. Private but read-only call: `CGSMoveWorkspacesToManagedDisplay` or `CGSSetActiveSpace` - test if works with full SIP on Tahoe. Many CGS setters still work without SIP disable.
  2. If blocked, fallback to simulating keypress Ctrl+Number (1-9) using `CGEvent` (requires Accessibility permission). Document trade-off.
  3. If that fails, show instruction: "Press Ctrl+2 to go to Terminal" - still useful.

### 5. Lifecycle

1. User drags app to /Applications
2. First launch: request notification permission for Space switch detection if needed, prompt for Accessibility ONLY if user enables switcher hotkey jump feature. Explain why.
3. `SMAppService.mainApp.register()` for login item (no LaunchDaemon)
4. NameStore loads plist, SpaceMonitor does initial scan
5. Menu bar shows current Space name

No Recovery reboot, no `csrutil` command.

### 6. Build and Distribution

- Language: Swift + small Objective-C shim for CGS dlsym
- Hardened runtime: YES, no `allow-dyld-environment-variables`, no `disable-library-validation` exception
- Notarized Developer ID distribution
- Optional Mac App Store target: Replace CGS calls with best-effort fallback using `CGWindowListCopyWindowInfo` heuristics if CGS symbols rejected during review. App Store build can work index-based only - acceptable degradation.
- Auto-update via Sparkle (outside App Store)

### 7. Failure Modes & Resilience

| Failure | Mitigation |
|---------|------------|
| `CGSCopyManagedDisplaySpaces` returns nil or changes format after update | Cache last known topology, fall back to index-only mode, show warning: "macOS changed Spaces API - names may shift until update" |
| No managedSpaceID available | Use display UUID + creationOrder heuristic, never crash |
| User disables "Displays have separate Spaces" | Re-scan all displays, re-map records by lastSeenIndex + display, prompt user to confirm |
| Accessibility permission denied | Switcher jump feature disabled, but naming and menu bar still work. Show non-blocking banner. |
| macOS update renumbers all Spaces | Detect mass mismatch (all spaces unmatched), offer to restore from JSON backup |

### 8. Testing Plan

- Test matrix: Tahoe + next beta, Apple Silicon + Intel, 1-3 displays, with and without "Displays have separate Spaces"
- Automated: Unit tests for diff algorithm with simulated topologies
- Manual: Add/remove Space at middle, restart Dock (`killall Dock`), restart machine, unplug display, change display arrangement

End of Technical Specifications.
