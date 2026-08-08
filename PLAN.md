# SpaceNameTool — Implementation Plan (SIP-Safe)

**Source of truth:** `docs/01-Requirements-SIP-Safe.md`, `docs/02-Technical-Specifications-SIP-Safe.md`, `docs/03-Security-Analysis-SIP-Safe.md`.

## Hard constraints

- Full SIP remains enabled; no `csrutil`, no LaunchDaemon, no privileged helper.
- No code injection into Dock, WindowServer, or any system process.
- CGS/SkyLight only via dlsym; read-only by default; Space switch setters only if they work under full SIP (later).
- Mission Control text replacement is closed.

## Priority (this session)

1. NameStore + topology-diff keying (ManagedSpaceID → display UUID + creationOrder).
2. SpaceMonitor (notification-first).
3. Menu bar shows current custom name.
4. Overlay / switcher remain stubs (no product wiring yet).

## Steps

1. Split `SpaceNameToolCore` library vs thin `SpaceNameTool` executable for `@testable` unit tests.
2. Align models with tech spec (`DisplayID`, `SpaceRecord`, archive, live topology types).
3. Implement pure `TopologyReconciler` + `NameStore` persistence (plist + JSON) with sanitization.
4. Unit-test reconcilation: match by ManagedSpaceID, reorder, insert middle, archive after 7 days.
5. Implement `CGSPrivate` dlsym load of SkyLight; parse `CGSCopyManagedDisplaySpaces`; degrade on failure.
6. Implement `SpaceMonitor`: `activeSpaceDidChangeNotification` first, distributed fallback, 1Hz last resort.
7. Wire `AppDelegate` + `MenuBarController` to NameStore/SpaceMonitor for status title.
8. `swift test` / build verification.

## Out of scope now

- Overlay bezel, switcher jump, SMAppService login item, config window, Accessibility key simulation.

## Risks

- CGS dictionary keys vary by macOS; parser must be defensive.
- Executable + library split may need path moves of existing stubs.
