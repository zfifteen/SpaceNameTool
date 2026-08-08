# FR / NFR Matrix — SpaceNameTool 1.0 SIP-Safe

Source of truth: `01-Requirements-SIP-Safe.md`. Evidence points to code, tests, or UX steps.

| ID | Requirement | Status | Evidence |
|----|-------------|--------|----------|
| FR-1 | Config window per-display names | **Done** | `ConfigurationView.swift`; menu “Configure Space Names…” |
| FR-2 | Menu bar current name ≤500ms | **Done** | `MenuBarController` + `NSWorkspace.activeSpaceDidChangeNotification` |
| FR-3 | Heads-Up overlay 1.5s | **Done** | `OverlayWindowController` |
| FR-4 | Custom switcher + jump | **Done** | `SwitcherWindowController`, Control+Space hotkey, `SpaceJumpService` / `JumpPolicy` |
| FR-5 | Names survive restart | **Done** | `NameStore` plist/json under Application Support; unit persist tests |
| FR-6 | Add/remove preserves names; prompt new | **Done** | `TopologyReconciler` + new-Space alert; archive revive |
| FR-7 | Separate Spaces on/off | **Done** (logic) | Multi-display keying tests; hardware UX optional |
| FR-8 | Reset all names | **Done** | Menu + config destructive action |
| FR-9 | Export/import JSON | **Done** | Config Export/Import + `NameStore.exportJSON` |
| FR-10 | 16×6 capacity | **Done** | Soft cap in store; FR-10 limit constant |
| NFR-1 | No Dock crash / SIP reduction | **Done** | Design + `docs/03`; no injection code paths |
| NFR-2 | SMAppService login item | **Done** | `LoginItemService`; toggle in config |
| NFR-3 | CPU/memory, no fast poll | **Done** | Notification-first; 1Hz max poll; see UX note |
| NFR-4 | Drag to /Applications | **Done** | `scripts/package-app.sh` → `dist/SpaceNameTool.app` |
| NFR-5 | Notarizable hardened runtime | **Partial** | Entitlements + ad-hoc sign; **Developer ID notarization blocked without credentials** |
| NFR-6 | VoiceOver / keyboard switcher | **Done** | Accessibility labels; ↑↓ Enter Esc in switcher |
| NFR-7 | No network / analytics | **Done** | No network code |

## Constraints

| Constraint | Status |
|------------|--------|
| Full SIP enabled | Confirmed on build host: `csrutil status` = enabled |
| No csrutil / LaunchDaemon / privileged helper | Met |
| CGS read-only (+ optional setActive in-process) via dlsym | Met |
| Mission Control strip closed | Met — no MC text replacement |
