//
//  MenuBarController.swift
//  SpaceNameTool
//
//  NSStatusItem showing the current Space's custom name (FR-2).
//  SIP-safe: AppKit UI in this process only.
//

import AppKit
import SpaceNameToolCore

/// Controls the menu-bar status item and primary user actions.
@MainActor
final class MenuBarController: NSObject, SpaceMonitorDelegate {
    private let nameStore: NameStore
    private let spaceMonitor: SpaceMonitor

    private var statusItem: NSStatusItem?
    private var activeRecord: SpaceRecord?
    private var allRecords: [SpaceRecord] = []

    init(nameStore: NameStore, spaceMonitor: SpaceMonitor) {
        self.nameStore = nameStore
        self.spaceMonitor = spaceMonitor
        super.init()
        self.spaceMonitor.delegate = self
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
        }
        item.menu = makeMenu()
        statusItem = item
        spaceMonitor.start()
        refreshTitle()
    }

    // MARK: - SpaceMonitorDelegate

    nonisolated func spaceMonitorDidUpdate(
        active: SpaceRecord?,
        allActive: [SpaceRecord],
        diff: TopologyDiffResult
    ) {
        Task { @MainActor in
            self.activeRecord = active
            self.allRecords = allActive
            self.refreshTitle()
            self.rebuildMenu()
            // FR-6: new spaces detected — menu will list them; overlay prompt later.
            _ = diff.newlyCreated
        }
    }

    nonisolated func spaceMonitorDegraded(reason: String) {
        Task { @MainActor in
            guard let button = self.statusItem?.button else { return }
            button.toolTip = reason
        }
    }

    // MARK: - UI

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let name = activeRecord?.displayName ?? "Spaces"
        // Truncate for menu bar density.
        let maxChars = 24
        if name.count > maxChars {
            let end = name.index(name.startIndex, offsetBy: maxChars - 1)
            button.title = String(name[..<end]) + "…"
        } else {
            button.title = name
        }
        if let index = activeRecord?.lastSeenIndex {
            button.toolTip = "Space \(index + 1): \(activeRecord?.displayName ?? name)"
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
            let empty = NSMenuItem(
                title: "No Spaces detected yet",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for record in allRecords {
                let marker = (record.persistentID == activeRecord?.persistentID) ? "✓ " : "    "
                let title = "\(marker)\(record.lastSeenIndex + 1). \(record.displayName)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Overlay / switcher deferred until naming + monitor are proven.
        let rename = NSMenuItem(
            title: "Rename Current Space…",
            action: #selector(renameCurrentSpace(_:)),
            keyEquivalent: "r"
        )
        rename.target = self
        rename.isEnabled = activeRecord != nil
        menu.addItem(rename)

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

    @objc private func renameCurrentSpace(_ sender: Any?) {
        guard let active = activeRecord else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Space \(active.lastSeenIndex + 1)"
        alert.informativeText = "Custom names appear in this app’s menu bar (not Mission Control)."
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
        alert.informativeText = "Spaces will fall back to “Desktop N”. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            nameStore.resetAllNames()
            spaceMonitor.refresh(reason: "reset")
        }
    }
}
