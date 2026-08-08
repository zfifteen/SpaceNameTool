# SpaceNameTool

macOS menu-bar utility that lets you assign **custom names to virtual desktops (Spaces)**.

## SIP-safe design

This project is built to keep **full System Integrity Protection (SIP) enabled**.

- **SIP-safe:** the app observes Spaces and stores names without weakening system integrity.
- **No code injection:** never injects into Dock, WindowServer, or any other system process.
- **No `csrutil` steps:** users do not run `csrutil disable` (or any related recovery commands).
- **Hardened runtime / notarization path:** public entitlements only; no private entitlements that block notarization.

Business logic (stable Space identity, keying algorithm, CGS read-only observation) is intentionally **not implemented** in this bootstrap skeleton. Wait for the SIP-safe specification documents before adding real implementation.

## Layout

```
SpaceNameTool/
├── Package.swift
├── README.md
├── PLAN.md
├── docs/                   # SIP-safe requirements / tech / security (source of truth)
├── Resources/Info.plist    # LSUIElement = true
├── Sources/
│   ├── SpaceNameToolCore/  # NameStore, topology diff, CGS dlsym, SpaceMonitor
│   └── SpaceNameTool/      # Menu bar app entry + deferred overlay/switcher
└── Tests/SpaceNameToolTests/
```

## Status

Core path implemented against `docs/*-SIP-Safe.md`:

1. **NameStore + topology-diff keying** (`ManagedSpaceID` first, then display UUID + `creationOrder`)
2. **SpaceMonitor** — notification-first (`NSWorkspace.activeSpaceDidChangeNotification`, distributed fallback)
3. **Menu bar** — shows current custom name; simple rename alert; list of Spaces

Deferred: Heads-Up overlay, custom switcher jump, Mission Control strip (closed permanently).

## Develop

```bash
cd ~/IdeaProjects/SpaceNameTool
swift test
swift build
# Run menu bar app (shows status item while process lives):
swift run SpaceNameTool
```

Specs: `docs/01-Requirements-SIP-Safe.md`, `docs/02-Technical-Specifications-SIP-Safe.md`, `docs/03-Security-Analysis-SIP-Safe.md`.

## License

TBD
