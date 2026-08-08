//
//  ConfigurationView.swift
//  SpaceNameTool
//
//  Configuration window (FR-1): per-display Space names, export/import, prefs.
//

import AppKit
import ServiceManagement
import SpaceNameToolCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ConfigurationWindowController: NSWindowController {
    private let nameStore: NameStore
    private let spaceMonitor: SpaceMonitor
    private let preferences: PreferencesStore

    init(nameStore: NameStore, spaceMonitor: SpaceMonitor, preferences: PreferencesStore) {
        self.nameStore = nameStore
        self.spaceMonitor = spaceMonitor
        self.preferences = preferences
        let view = ConfigurationView(
            nameStore: nameStore,
            spaceMonitor: spaceMonitor,
            preferences: preferences
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Space Name Tool"
        window.setContentSize(NSSize(width: 640, height: 480))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct ConfigurationView: View {
    let nameStore: NameStore
    let spaceMonitor: SpaceMonitor
    @ObservedObject var preferences: PreferencesStore

    @State private var records: [SpaceRecord] = []
    @State private var selectedDisplayKey: String = ""
    @State private var draftNames: [String: String] = [:]
    @State private var loginStatus: String = LoginItemService.statusDescription
    @State private var statusMessage: String = ""

    private let debounce = DebouncedAction(delay: 0.2)

    var body: some View {
        NavigationSplitView {
            List(displayKeys, id: \.self, selection: $selectedDisplayKey) { key in
                Text(displayTitle(for: key))
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 180)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if spacesForSelection.isEmpty {
                    Text("No Spaces on this display yet. Use Refresh after switching Spaces.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(spacesForSelection, id: \.persistentID) { record in
                            HStack {
                                Text("\(record.lastSeenIndex + 1).")
                                    .frame(width: 28, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "Name",
                                    text: binding(for: record)
                                )
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Name for Desktop \(record.lastSeenIndex + 1)")
                            }
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Form {
                    Section("Preferences") {
                        Toggle("Show name overlay when switching Spaces", isOn: $preferences.overlayEnabled)
                        Toggle("Show index in menu bar (N: Name)", isOn: $preferences.showIndexInMenuBar)
                        Toggle("Launch at login", isOn: Binding(
                            get: { preferences.launchAtLogin },
                            set: { newValue in
                                preferences.launchAtLogin = newValue
                                applyLoginItem(newValue)
                            }
                        ))
                        Text("Login item: \(loginStatus)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxHeight: 180)

                HStack {
                    Button("Refresh Spaces") {
                        spaceMonitor.refresh(reason: "config")
                        reload()
                    }
                    Button("Export JSON…") { exportJSON() }
                    Button("Import JSON…") { importJSON() }
                    Spacer()
                    Button("Reset All Names…", role: .destructive) { resetAll() }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .onAppear {
            reload()
            if selectedDisplayKey.isEmpty, let first = displayKeys.first {
                selectedDisplayKey = first
            }
            loginStatus = LoginItemService.statusDescription
        }
    }

    private var displayKeys: [String] {
        let keys = Set(records.map { displayKey($0.display) })
        return keys.sorted()
    }

    private var spacesForSelection: [SpaceRecord] {
        records
            .filter { displayKey($0.display) == selectedDisplayKey }
            .sorted { $0.lastSeenIndex < $1.lastSeenIndex }
    }

    private func displayKey(_ d: DisplayID) -> String {
        if let u = d.uuidString, !u.isEmpty { return u }
        return "cg-\(d.cgDirectDisplayID)"
    }

    private func displayTitle(for key: String) -> String {
        records.first { displayKey($0.display) == key }?.display.localizedName ?? key
    }

    private func binding(for record: SpaceRecord) -> Binding<String> {
        Binding(
            get: { draftNames[record.persistentID] ?? record.customName },
            set: { newValue in
                draftNames[record.persistentID] = newValue
                let id = record.persistentID
                debounce.schedule {
                    nameStore.setCustomName(newValue, persistentID: id)
                    statusMessage = "Saved “\(NameSanitizer.sanitize(newValue))”"
                    reload()
                }
            }
        )
    }

    private func reload() {
        records = nameStore.allRecords(includeArchived: false)
        for r in records {
            if draftNames[r.persistentID] == nil {
                draftNames[r.persistentID] = r.customName
            }
        }
    }

    private func applyLoginItem(_ enabled: Bool) {
        do {
            _ = try LoginItemService.setEnabled(enabled)
            loginStatus = LoginItemService.statusDescription
            statusMessage = "Launch at login: \(loginStatus)"
        } catch {
            loginStatus = LoginItemService.statusDescription
            statusMessage = "Login item error: \(error.localizedDescription). Package as .app for best results."
            preferences.launchAtLogin = LoginItemService.isEnabled
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "SpaceNameTool-names.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try nameStore.exportJSON()
            try data.write(to: url, options: .atomic)
            statusMessage = "Exported to \(url.lastPathComponent)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let alert = NSAlert()
            alert.messageText = "Import name map?"
            alert.informativeText = "Replace all stored names, or merge by persistent ID?"
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Merge")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertThirdButtonReturn { return }
            try nameStore.importJSON(data, replace: response == .alertFirstButtonReturn)
            draftNames = [:]
            reload()
            spaceMonitor.refresh(reason: "import")
            statusMessage = "Import complete"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func resetAll() {
        let alert = NSAlert()
        alert.messageText = "Reset all custom names?"
        alert.informativeText = "Spaces fall back to “Desktop N”."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        nameStore.resetAllNames()
        draftNames = [:]
        reload()
        statusMessage = "All names reset"
    }
}
