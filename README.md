![SpaceNameTool](docs/assets/hero.png)

# SpaceNameTool

### Stop guessing which desktop is which.

You already live in Spaces. Terminal on one. Browser on another. That messy “I’ll sort it later” desk on a third. macOS still calls them **Desktop 1, Desktop 2, Desktop 3** — like filing cabinets labeled “Drawer.”

**SpaceNameTool** puts **your** names on them: **Terminal. Research. Deep Work. Admin.** Right in the menu bar. Right when you switch. Right when you search.

### What you get

**A name for every Space that actually sticks.**  
Rename once. Restart the Mac. Add a Space in the middle. Unplug a display. The names that matter stay attached to the Spaces that matter — because the app was built around identity, not fragile “Desktop number” guessing.

**A menu bar that tells the truth.**  
Glance up. You’re on **Code**, not “Desktop 4.” Switch, and it updates with you. No hunting Mission Control. No squinting at wallpaper.

**A quiet heads-up when you land.**  
Swipe or Control+Arrow into a Space — a soft bezel says the name, then gets out of your way. Orientation without theater.

**A switcher that speaks your language.**  
Control+Space. Type part of a name. Arrow. Enter. Jump toward the desktop you *mean*, not the one you counted on your fingers.

**A config window for the whole map.**  
Every display. Every Space. Edit names where you can see the layout. Export a JSON backup. Import it on the next machine. Reset when you want a clean slate.

**Launch at login, stay out of the Dock.**  
It lives in the menu bar where utility belongs — present when you need it, invisible when you don’t.

### The pitch nobody else can honestly make

Most “rename my Spaces” ideas whisper the same dark bargain: **weaken the Mac.** Turn off System Integrity Protection. Inject into Dock. Run something privileged. Trade security for labels.

**SpaceNameTool refuses that deal.**

- **Full SIP stays on.**
- **No code injection** into Dock, WindowServer, or anything system.
- **No Recovery reboot. No `csrutil` ritual. No daemon as root.**
- Names live in **your** Application Support folder — your data, your machine, your rules.
- Private APIs? Only as **read-first observation** (and careful, optional switch), loaded dynamically, fail closed if Apple moves the furniture.

You’re not installing a clever rootkit with a UI. You’re installing a **user-space product** that respects the security model Apple actually supports — and still solves the problem you feel every day.

That’s the product: **clarity without compromise.**

### Who this is for

- Anyone who runs **more than two Spaces** and has ever said “wait, was that left or right?”
- Developers, writers, researchers, ops — people with **contexts**, not just windows.
- Multi-display setups where “Desktop 2” means nothing and **Mail** means everything.
- People who want power tools that **don’t require turning the machine into a science experiment.**

If Mission Control is a hallway of identical doors, SpaceNameTool is the **nameplate on each one** — engraved by you, remembered by the app, never painted over the OS in a way that breaks the house.

### The close

Yes — it’s free. Open. MIT.

That doesn’t make the *idea* free.

The idea is: **your attention is expensive**, and nameless desktops tax it all day. SpaceNameTool is the smallest serious tool that pays that tax back — in the menu bar, on the switch, in the switcher — while **keeping SIP intact and the Dock untouched.**

Install it. Name one Space **Deep Work**. Switch to it once.

You’ll feel the difference between living on a Mac… and living on *your* Mac.

**SpaceNameTool** — *Your desktops. Your names. Full SIP. Zero injection.*

---

## Overview

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
swift test          # unit tests
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

**1.0 product** against the SIP-safe FR/NFR set (see matrix). Validated in real use; optional remaining work includes Developer ID notarization and multi-monitor hardware matrix notes.

## License

MIT — see [LICENSE](LICENSE).
