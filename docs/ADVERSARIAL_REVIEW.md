# Adversarial Code Review — SpaceNameTool SIP-Safe 1.0

**Date:** 2026-08-08  
**Scope:** Full tree under `Sources/`, packaging, persistence, CGS layer  
**Method:** Spec-driven threat model (docs/03) + identity integrity (docs/02) + concurrency + resources  

## Summary

| Severity | Open | Remediated in this pass |
|----------|------|-------------------------|
| Critical | 0 | 0 found |
| High | 0 | 2 fixed |
| Medium | 0 | 3 fixed |
| Low | 2 residual | documented |

## Findings

### H1 — Archived names never revived on ManagedSpaceID return (FR-6)

- **Evidence:** `TopologyReconciler` matched only non-archived records; reappearance after archive created a **new** empty name.
- **Remediation:** Pass 0 revives archived records by `managedSpaceID` before creating new IDs. Covered by `testArchiveReappearsByManagedID`.

### H2 — Optional Space switch must not imply injection

- **Evidence:** Jump ladder needs a switch path.
- **Remediation:** `CGSSetActiveSpace` via dlsym **in-process only**; fail closed to CGEvent Ctrl+Number or instruction UI. No Dock/WindowServer injection. Documented in `SpaceJumpService` / security analysis alignment.

### M1 — Active Space resolution when managed id missing

- **Remediation:** `SpaceMonitor.resolveActiveRecord` static helper with index-sorted fallback. Unit tested.

### M2 — New Space silent until menu open (FR-6 prompt)

- **Remediation:** Menu bar prompts once per `persistentID` for `diff.newlyCreated`.

### M3 — Corrupt plist could confuse first launch

- **Remediation:** Load fails closed to empty document; `testCorruptPlistDoesNotCrash`.

### L1 residual — Carbon hotkey may collide with system Control+Space

- **Mitigation:** User can open switcher from menu; key code stored in prefs for future rebinding UI.

### L2 residual — Local event monitor for switcher keys is process-wide while window open

- **Mitigation:** Handler returns unhandled events when switcher is not key; no global keylogging EventTap.

## Security checklist (docs/03)

| Check | Result |
|-------|--------|
| Full SIP retained | Yes — no csrutil, no sealed-system writes |
| No code injection | Yes — no DYLD insert, no task_for_pid |
| No LaunchDaemon / privileged helper | Yes — SMAppService login item only |
| NameStore user-domain only | Yes — Application Support |
| Name length / control strip | Yes — `NameSanitizer` max 50 |
| Network / analytics | None |
| Hardened runtime entitlements | `SpaceNameTool.entitlements` omits injection exceptions |
| CGS fail closed | Yes — `Result` / degrade message |

## Concurrency

- `NameStore` serializes on private queue; concurrent `setCustomName` tested.
- UI updates hop to `@MainActor` from monitor callbacks.

## Resources (NFR-3)

- Notification-first; 1Hz poll only when forced / CGS unavailable.
- Overlay dismiss timer cancelled on dismiss; monitor timer invalidated on stop.

## Residual operator actions

1. Notarization with Apple credentials (see `docs/PACKAGING.md`).
2. Multi-display hardware UX pass if more than one monitor available.
3. Full machine reboot persistence confirmation on the operator’s Mac.
