# UX Acceptance Checklist — SpaceNameTool 1.0

**Host:** build machine  
**SIP:** enabled (`csrutil status`)  
**Build:** `scripts/package-app.sh` → `dist/SpaceNameTool.app` (ad-hoc signed)  
**Date:** 2026-08-08  

## Automated (agent)

| # | Step | Result |
|---|------|--------|
| A1 | `swift test` (29 tests) | **Pass** |
| A2 | Release package builds `.app` | **Pass** |
| A3 | Spec docs present; no injection paths in tree | **Pass** (grep / review) |

## Manual product UX (operator)

Run: open `dist/SpaceNameTool.app` (or `swift run SpaceNameTool`). Grant Accessibility only if testing Ctrl+Number jump.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 1 | Menu bar appears (no Dock icon) | **Ready for operator** | LSUIElement / accessory policy |
| 2 | Configure → name Space 2 “Terminal” | **Ready for operator** | |
| 3 | Switch to Space 2; menu bar shows Terminal | **Ready for operator** | Target &lt;500ms |
| 4 | Overlay shows name ~1.5s on switch | **Ready for operator** | Toggle in preferences |
| 5 | Control+Space opens switcher; filter + Enter | **Ready for operator** | Jump may instruct if CGS/AX denied |
| 6 | Add Space mid-list; old names hold; prompt for new | **Ready for operator** | FR-6 |
| 7 | Export JSON; import replace | **Ready for operator** | |
| 8 | Reset all names with confirm | **Ready for operator** | |
| 9 | Launch at login toggle | **Blocked until .app login item approved** | Better after /Applications install |
| 10 | Quit cleanly | **Ready for operator** | |
| 11 | Relaunch after quit: names persist | **Ready for operator** | Full reboot optional |
| 12 | Multi-display naming | **Blocked without 2nd display** | Unit tests cover dual-display keying |

## Resource spot-check (NFR-3)

Idle after launch: notification-driven design; poll ≤1Hz only when CGS unavailable. Operator may sample Activity Monitor (expect &lt;80MB, low idle CPU).

## Sign-off

| Role | Status |
|------|--------|
| Automated quality | **Pass** (29/29 unit tests, package script) |
| Interactive UX | **Operator pass required** for steps 1–11 on a live Spaces session |
| Notarization | **Blocked** without Developer ID / notary profile |
