//
//  MenuBarController.swift
//  SpaceNameTool
//
//  NSStatusItem showing the current Space's custom name (FR-2).
//  Wires overlay, switcher, config, and new-Space prompts.
//

import AppKit
import SpaceNameToolCore

@MainActor
final class MenuBarController: NSObject, SpaceMonitorDelegate {
    private let nameStore: NameStore
    private let spaceMonitor: SpaceMonitor
    private let preferences: PreferencesStore

    private var statusItem: NSStatusItem?
    private var activeRecord: SpaceRecord?
    private var allRecords: [SpaceRecord] = []
    private var previousActiveID: String?
    private var isInitialUpdate = true
    private var promptedNewSpaceIDs = Set<String>()

    private let overlay = OverlayWindowController()
    private let switcher = SwitcherWindowController()
    private var configWindow: ConfigurationWindowController?
    private let hotkey = HotkeyService()

    init(nameStore: NameStore, spaceMonitor: SpaceMonitor, preferences: PreferencesStore) {
        self.nameStore = nameStore
        self.spaceMonitor = spaceMonitor
        self.preferences = preferences
        super.init()
        self.spaceMonitor.delegate = self
        switcher.onJump = { record in
            SpaceJumpService.jump(to: record)
        }
    }

    func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.3x1",
                accessibilityDescription: "Space Name Tool"
            )
            button.imagePosition = .imageLeading
            button.title = "Spaces"
            button.setAccessibilityLabel("Space Name Tool")
        }
        item.menu = makeMenu()
        statusItem = item

        hotkey.register(keyCode: preferences.switcherHotkeyKeyCode) { [weak self] in
            self?.showSwitcher()
        }

        spaceMonitor.start()
        refreshTitle()
    }

    func teardown() {
        hotkey.unregister()
        spaceMonitor.stop()
        overlay.dismiss()
        statusItem = nil
    }

    // MARK: - SpaceMonitorDelegate

    nonisolated func spaceMonitorDidUpdate(
        active: SpaceRecord?,
        allActive: [SpaceRecord],
        diff: TopologyDiffResult
    ) {
        Task { @MainActor in
            self.handleUpdate(active: active, allActive: allActive, diff: diff)
        }
    }

    nonisolated func spaceMonitorDegraded(reason: String) {
        Task { @MainActor in
            self.statusItem?.button?.toolTip = reason
        }
    }

    private func handleUpdate(
        active: SpaceRecord?,
        allActive: [SpaceRecord],
        diff: TopologyDiffResult
    ) {
        allRecords = allActive
        activeRecord = active
        refreshTitle()
        rebuildMenu()

        // FR-6: prompt once for newly created Spaces.
        for record in diff.newlyCreated where !promptedNewSpaceIDs.contains(record.persistentID) {
            promptedNewSpaceIDs.insert(record.persistentID)
            promptNameForNewSpace(record)
        }

        // FR-3: overlay on active change (skip first paint).
        if isInitialUpdate {
            isInitialUpdate = false
            previousActiveID = active?.persistentID
            return
        }
        if let active, active.persistentID != previousActiveID {
            previousActiveID = active.persistentID
            if preferences.overlayEnabled {
                overlay.present(for: active)
            }
        } else {
            previousActiveID = active?.persistentID
        }
    }

    // MARK: - UI

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let base = activeRecord?.displayName ?? "Spaces"
        let name: String
        if preferences.showIndexInMenuBar, let index = activeRecord?.lastSeenIndex {
            name = "\(index + 1): \(base)"
        } else {
            name = base
        }
        let maxChars = 24
        if name.count > maxChars {
            let end = name.index(name.startIndex, offsetBy: maxChars - 1)
            button.title = String(name[..<end]) + "…"
        } else {
            button.title = name
        }
        if let active = activeRecord {
            button.toolTip = "Space \(active.lastSeenIndex + 1): \(active.displayName)"
            button.setAccessibilityLabel("Current Space \(active.displayName)")
        }
    }

    private func rebuildMenu() {
        statusItem?.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let currentTitle: String
        if let active = activeRecord {
            currentTitle = "Current: \(active.displayName)"
        } else {
            currentTitle = "Current Space: Unknown"
        }
        let current = NSMenuItem(title: currentTitle, action: nil, keyEquivalent: "")
        current.isEnabled = false
        menu.addItem(current)

        menu.addItem(.separator())

        if allRecords.isEmpty {
            let empty = NSMenuItem(title: "No Spaces detected yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for record in allRecords {
                let marker = (record.persistentID == activeRecord?.persistentID) ? "✓ " : "    "
                let title = "\(marker)\(record.lastSeenIndex + 1). \(record.displayName)"
                let item = NSMenuItem(title: title, action: #selector(jumpToSpace(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = record.persistentID
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let configure = NSMenuItem(
            title: "Configure Space Names…",
            action: #selector(openConfiguration(_:)),
            keyEquivalent: ","
        )
        configure.target = self
        menu.addItem(configure)

        let rename = NSMenuItem(
            title: "Rename Current Space…",
            action: #selector(renameCurrentSpace(_:)),
            keyEquivalent: "r"
        )
        rename.target = self
        rename.isEnabled = activeRecord != nil
        menu.addItem(rename)

        let switcherItem = NSMenuItem(
            title: "Show Space Switcher…",
            action: #selector(showSwitcherMenu(_:)),
            keyEquivalent: "s"
        )
        switcherItem.target = self
        menu.addItem(switcherItem)

        let refresh = NSMenuItem(
            title: "Refresh Spaces",
            action: #selector(refreshSpaces(_:)),
            keyEquivalent: "r"
        )
        refresh.keyEquivalentModifierMask = [.command, .shift]
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let reset = NSMenuItem(
            title: "Reset All Names…",
            action: #selector(resetAllNames(_:)),
            keyEquivalent: ""
        )
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit SpaceNameTool",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    private func promptNameForNewSpace(_ record: SpaceRecord) {
        let alert = NSAlert()
        alert.messageText = "New Space detected"
        alert.informativeText = "Name Desktop \(record.lastSeenIndex + 1)? Custom names appear in this app only (Mission Control strip is unchanged)."
        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Skip")
        if alert.runModal() == .alertFirstButtonReturn {
            nameStore.setCustomName(field.stringValue, persistentID: record.persistentID)
            spaceMonitor.refresh(reason: "new-space-named")
        }
    }

    @objc private func openConfiguration(_ sender: Any?) {
        if configWindow == nil {
            configWindow = ConfigurationWindowController(
                nameStore: nameStore,
                spaceMonitor: spaceMonitor,
                preferences: preferences
            )
        }
        configWindow?.show()
    }

    @objc private func showSwitcherMenu(_ sender: Any?) {
        showSwitcher()
    }

    private func showSwitcher() {
        switcher.present(spaces: nameStore.allRecords(includeArchived: false))
    }

    @objc private func jumpToSpace(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let record = nameStore.record(persistentID: id) else { return }
        if let message = SpaceJumpService.jump(to: record) {
            let alert = NSAlert()
            alert.messageText = "Switch Space"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            if message.contains("Control+") {
                alert.addButton(withTitle: "Request Accessibility…")
                if alert.runModal() == .alertSecondButtonReturn {
                    SpaceJumpService.requestAccessibilityIfNeeded()
                }
            } else {
                alert.runModal()
            }
        }
    }

    @objc private func renameCurrentSpace(_ sender: Any?) {
        guard let active = activeRecord else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Space \(active.lastSeenIndex + 1)"
        alert.informativeText = "Custom names appear in this app’s menu bar and overlay (not Mission Control)."
        alert.alertStyle = .informational
        let field = NSTextField(string: active.customName)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            nameStore.setCustomName(field.stringValue, persistentID: active.persistentID)
            activeRecord = nameStore.record(persistentID: active.persistentID)
            refreshTitle()
            rebuildMenu()
        }
    }

    @objc private func refreshSpaces(_ sender: Any?) {
        spaceMonitor.refresh(reason: "menu")
    }

    @objc private func resetAllNames(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Reset all custom names?"
        alert.informativeText = "Spaces will fall back to “Desktop N”."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            nameStore.resetAllNames()
            spaceMonitor.refresh(reason: "reset")
        }
    }
}
