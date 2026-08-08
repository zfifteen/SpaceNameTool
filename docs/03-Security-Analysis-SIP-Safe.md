# Security Analysis
## Custom Space Name Tool for macOS - SIP-Safe Edition

**Version:** 1.0  
**Date:** 2026-08-08  
**Status:** Draft for build  
**Comparison:** This replaces the injection-based analysis that required SIP disable.

### 1. Purpose

Describe security posture of SIP-safe implementation. No SIP changes, no injection, no root.

### 2. Required System Changes

**None.**

- No `csrutil disable` or `csrutil enable --without ...`
- No authenticated-root disable
- No modification of /System, /Library, or sealed system volume
- No LaunchDaemon, no privileged helper, no `SMJobBless`
- No task_for_pid, no DYLD injection

Installation is standard drag-to-Applications.

### 3. What Remains Protected (Full SIP)

All protections that were removed in v0.1 now remain active:

- System file protection (FS) - system binaries not writable by root
- Kernel extension signing enforcement
- Debugging protection for system processes (Dock, WindowServer, loginwindow cannot be injected)
- NVRAM and boot arg protection
- Secure Boot and SSV integrity on Apple Silicon

This is the default macOS security posture that Apple tests and supports.

### 4. Attack Surface of This Tool

| Component | Privileges | Risk |
|-----------|------------|------|
| Main app process | User, hardened runtime, no special entitlements (except optional Accessibility if user enables hotkey jump) | Same as any menu bar app. Bug can only affect its own process, not Dock. |
| NameStore plist | `~/Library/Application Support/` - user-writable | Malicious write can only corrupt display names (DoS of feature), cannot achieve code execution. We validate string length (max 50 chars), strip control characters, limit count. |
| CGS read-only calls via dlsym | No privilege, no entitlement | If Apple removes symbols, we degrade gracefully. No memory corruption risk beyond CFArray handling - use safe bridging. |
| Overlay panel / Switcher window | User-level windows | Cannot become keylogger, cannot intercept secure input. |
| Accessibility permission (optional) | Only if user enables "Jump to Space via hotkey" | Scoped: used only for posting Ctrl+Number key events. Requested with clear purpose string. User can deny and app still works 90%. |

**No TCC bypass.** We do NOT run inside Dock, so we do NOT inherit Dock's camera, mic, location, or automation entitlements.

**No persistence mechanism beyond standard Login Item** (`SMAppService`). User can disable in System Settings -> General -> Login Items. No hidden LaunchAgent.

### 5. Comparison to v0.1 Injection Version

| Risk | v0.1 Injection | v1.0 SIP-Safe |
|------|----------------|---------------|
| Malware can inject into Dock | Greatly increased (SIP off) | No change from stock macOS |
| System binaries writable | Yes if FS disabled | No |
| Unsigned kexts loadable | Easier | No |
| Dock crash loop | Possible, system restarts Dock automatically but plugin reloads -> loop | Impossible - we never touch Dock |
| Supply chain: injector as rootkit | Yes - injector is perfect persistence | No injector |
| Gatekeeper / XProtect flagged | Likely flagged as potentially unwanted | Not flagged, standard notarized app |

The security delta is not incremental - it's categorical. v0.1 moves machine to unsupported state. v1.0 stays in Apple-supported state.

### 6. Residual Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Custom name contains malicious Unicode (RTL override, etc.) | Low | Low | Sanitize: trim, limit length 50, normalize, strip control chars, render as plain text only |
| CGS API changes causing mis-identification of Space | Medium | Low | Diff algorithm archives old records instead of deleting, prompt user, never auto-delete |
| User grants Accessibility then forgets | Low | Low | Use only for synthetic Ctrl+Number, no event tap listening to all keys unless needed for hotkey. Show in prefs whether Accessibility is active. |
| Plist tampering by other user app | Low | Low | Plist is user-writable by design; worst case is wrong name displayed. Validate JSON schema on import. |

### 7. Privacy

- No network calls. No analytics, no crash reporter that sends data off-device without opt-in.
- Names never leave device. Export is manual JSON file user controls.
- No access to camera, mic, location, contacts, files beyond own container.

### 8. Uninstall and Recovery

1. Quit app
2. Drag app to Trash
3. Optionally delete `~/Library/Application Support/SpaceNameTool/`

No Recovery reboot, no `csrutil enable` needed. System returns to exactly pre-install state.

### 9. Recommendation

Proceed with this SIP-safe design. It meets the user's core need (knowing which Space is which) without violating macOS security model. It is buildable, maintainable, notarizable, and supportable across macOS updates.

If later you still want Mission Control strip modification, ship it as a separate, clearly labeled "Experimental - Requires Full SIP Disable - For Secondary Macs Only" extension, not as the main product. Keep main product SIP-safe.

End of Security Analysis.
