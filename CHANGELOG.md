# Changelog

## 1.0.0 — 2026-08-08

### SIP-safe product complete (docs 01–03)

- NameStore with ManagedSpaceID-first topology reconciliation, archive + revive
- CGS/SkyLight read (and optional setActive) via dlsym; graceful degrade
- SpaceMonitor notification-first with 1Hz poll fallback
- Menu bar current name, rename, reset, jump list
- Configuration window (per-display names, prefs, export/import)
- Heads-Up overlay (1.5s)
- Switcher palette (Control+Space), keyboard navigation, jump ladder
- SMAppService launch-at-login toggle
- Packaging script + hardened-runtime entitlements
- 29 unit tests; adversarial review document

### Security

- Full SIP retained; no injection; no privileged helper
- Mission Control strip replacement remains closed
