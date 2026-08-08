# Packaging & Distribution

## Build a drag-installable app

```bash
cd ~/IdeaProjects/SpaceNameTool
./scripts/package-app.sh
# → dist/SpaceNameTool.app
```

Drag `dist/SpaceNameTool.app` to `/Applications`.

## Entitlements

`SpaceNameTool.entitlements` enables hardened-runtime packaging without:

- `com.apple.security.cs.allow-dyld-environment-variables`
- `com.apple.security.cs.disable-library-validation`
- private injection or Dock-related entitlements

Sandbox is **off** so CGS/SkyLight observation and optional CGEvent jump remain available for a Developer ID (non–Mac App Store) build.

## Codesign

| Environment | Behavior |
|-------------|----------|
| `CODESIGN_IDENTITY` set | Signs with that identity + hardened runtime |
| Developer ID Application in keychain | Auto-detected |
| Neither | Ad-hoc sign (`codesign -s -`) for local run |

## Notarization (optional, NFR-5 full)

Requires Apple Developer Program credentials:

```bash
# Store credentials once:
xcrun notarytool store-credentials "SpaceNameTool-notary" \
  --apple-id "YOU@example.com" --team-id "TEAMID" --password "app-specific-password"

export NOTARY_PROFILE="SpaceNameTool-notary"
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/package-app.sh
```

Without credentials, the app remains **functionally complete** and **SIP-safe** on the local Mac; Gatekeeper may require right-click → Open for ad-hoc builds.

## Dev run (no package)

```bash
swift run SpaceNameTool
```

Login items (`SMAppService`) are more reliable for a true `.app` bundle than a raw SPM binary.
