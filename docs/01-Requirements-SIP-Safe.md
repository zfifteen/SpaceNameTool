# Requirements Document
## Custom Space Name Tool for macOS - SIP-Safe Edition

**Version:** 1.0  
**Date:** 2026-08-08  
**Status:** Draft for build  
**Supersedes:** 0.1 Injection-based draft

### 1. Purpose

The tool lets a user assign a permanent custom name to each macOS Space (virtual desktop) **without disabling System Integrity Protection (SIP) and without injecting code into system processes**.

The custom name appears in the tool's own UI - menu bar, Heads-Up overlay, and custom switcher - not by modifying the Mission Control strip. This preserves full system security.

### 2. Goals

- Allow user to assign custom text to each Space
- Names survive logout, restart, and macOS updates
- Zero change to SIP, no Recovery reboot, no root daemon
- Support Apple Silicon and Intel on macOS Tahoe (26) and later
- Work with "Displays have separate Spaces" on or off
- Notarizable and potentially Mac App Store compatible
- Dock process never touched

### 3. Non-Goals

- Modify Mission Control's "Desktop 1" strip text
- Change internal order or identity of Spaces
- Require `csrutil disable` or authenticated-root changes
- Provide a full window manager / tiling manager
- Inject into Dock, Finder, or SkyLight

### 4. Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | User can open a configuration window and type a custom name for any existing Space, listed per-display. | Must |
| FR-2 | Menu bar item shows custom name of currently active Space (e.g., "▣ Terminal") and updates within 500ms of a Space switch. | Must |
| FR-3 | Heads-Up overlay: When user switches Spaces (Ctrl+Arrow or 3-finger swipe), a non-intrusive bezel shows custom name for 1.5s. | Should |
| FR-4 | Custom switcher: Hotkey (e.g., Ctrl+Space) opens a palette listing all Spaces with custom names, allows jumping to a Space. | Should |
| FR-5 | Names survive logout, restart, and macOS updates. | Must |
| FR-6 | When user adds or removes a Space, tool preserves names for existing Spaces and prompts for new ones. No silent data loss. | Must |
| FR-7 | Works when "Displays have separate Spaces" is enabled or disabled. | Must |
| FR-8 | Reset all names to default "Desktop N" with one action, with confirmation. | Should |
| FR-9 | Export/import name map as JSON for backup/migration. | Should |
| FR-10 | Handles up to 16 Spaces per display (macOS limit) and 6 displays. | Must |

### 5. Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Must NOT crash Dock, WindowServer, or require SIP reduction. | Must |
| NFR-2 | Launch at login via SMAppService (no root, no LaunchDaemon). User-toggleable. | Must |
| NFR-3 | CPU <1% idle, memory <80MB. No polling loop faster than 1Hz. Use notifications where possible. | Must |
| NFR-4 | Installation: drag to /Applications, double-click. No Terminal commands. | Must |
| NFR-5 | Notarizable with Developer ID, hardened runtime, no private entitlement exceptions beyond what Apple allows for notarization. | Must |
| NFR-6 | Accessibility: VoiceOver reads Space names, keyboard navigable switcher. | Should |
| NFR-7 | Privacy: No network access, no analytics. | Must |

### 6. Constraints

- Must use only APIs that work with full SIP enabled. Reading private CGS/SkyLight functions is allowed; writing/injecting is not.
- No code injection, no DYLD_INSERT_LIBRARIES, no task_for_pid on protected processes.
- Custom names are stored in user domain only: ~/Library/Application Support/
- Space identity is inherently fragile - must handle reordering gracefully (see Tech Spec).

### 7. Acceptance Criteria

1. On a Mac with full SIP (`csrutil status` = enabled), user installs app without Recovery.
2. User assigns "Terminal" to the second Space on main display.
3. Menu bar shows "Terminal" when that Space is active.
4. After full restart, menu bar still shows "Terminal" for that Space.
5. User adds a new Space at position 2 - previous "Terminal" stays attached to its original Space, not shifted by index.
6. Dock never crashes; `spindump` shows no Dock modifications.

### 8. Open Questions

- Most reliable notification for Space switch on Tahoe: `NSWorkspace.activeSpaceDidChangeNotification` vs `CGS` callbacks vs polling `CGSGetActiveSpace`?
- Best fallback for switching Spaces without SIP: private `CGSMoveWorkspacesToManagedDisplay` vs simulating Ctrl+Number keys?
- Should we support per-display naming collisions (e.g., "Code" on Display 1 and Display 2)?

End of Requirements Document.
