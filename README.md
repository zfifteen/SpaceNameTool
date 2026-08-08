![SpaceNameTool](docs/assets/hero.png)

# SpaceNameTool

macOS **menu-bar** utility for **custom virtual desktop (Space) names**, built to the **SIP-safe** specification in `docs/`.

Custom names appear in **this app** (menu bar, overlay, switcher, configuration). The Mission Control “Desktop N” strip is **not** modified.

## Security posture

- **Full System Integrity Protection stays enabled**
- **No code injection** into Dock, WindowServer, or any system process
- **No `csrutil`**, Recovery steps, LaunchDaemon, or privileged helper
- Private CGS/SkyLight only via **dlsym**, fail closed if symbols disappear
- Names live in `~/Library/Application Support/SpaceNameTool/` only

## Install

```bash
./scripts/package-app.sh
# Drag dist/SpaceNameTool.app to /Applications
```

Details: [`docs/PACKAGING.md`](docs/PACKAGING.md). Notarization needs a Developer ID (optional).

## Use

1. Launch the app (menu bar item; no Dock icon).
2. **Configure Space Names…** (or rename from the menu).
3. Switch Spaces — menu bar updates; overlay shows the name ~1.5s.
4. **Control+Space** opens the switcher (filter, ↑↓, Enter to jump).
5. Optional: **Launch at login** in the configuration window.

Jump order: in-process `CGSSetActiveSpace` → Control+Number (Accessibility) → on-screen instruction.

## Develop

```bash
swift test          # 29 unit tests
swift run SpaceNameTool
```

## Documentation

| Doc | Purpose |
|-----|---------|
| [`docs/01-Requirements-SIP-Safe.md`](docs/01-Requirements-SIP-Safe.md) | Requirements |
| [`docs/02-Technical-Specifications-SIP-Safe.md`](docs/02-Technical-Specifications-SIP-Safe.md) | Architecture & keying |
| [`docs/03-Security-Analysis-SIP-Safe.md`](docs/03-Security-Analysis-SIP-Safe.md) | Security analysis |
| [`docs/FR_NFR_MATRIX.md`](docs/FR_NFR_MATRIX.md) | Completion matrix |
| [`docs/ADVERSARIAL_REVIEW.md`](docs/ADVERSARIAL_REVIEW.md) | Adversarial review |
| [`docs/UX_ACCEPTANCE.md`](docs/UX_ACCEPTANCE.md) | UX checklist |
| [`docs/PACKAGING.md`](docs/PACKAGING.md) | Ship path |
| [`CHANGELOG.md`](CHANGELOG.md) | Release notes |

## Layout

```
Sources/SpaceNameToolCore/   # NameStore, topology, CGS, monitor, jump policy
Sources/SpaceNameTool/       # Menu bar, config, overlay, switcher, login item
Tests/SpaceNameToolTests/
scripts/package-app.sh
Resources/Info.plist
```

## Status

**1.0 product code complete** against SIP-safe FR/NFR (see matrix).  
**Operator remaining:** live Spaces UX walkthrough, optional notarization, multi-monitor hardware check.

## License

MIT — see [LICENSE](LICENSE).
