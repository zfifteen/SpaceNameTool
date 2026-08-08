//
//  SwitcherWindowController.swift
//  SpaceNameTool
//
//  Custom switcher palette (FR-4). Keyboard navigable (NFR-6).
//

import AppKit
import SpaceNameToolCore

@MainActor
final class SwitcherWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private var allRecords: [SpaceRecord] = []
    private var filtered: [SpaceRecord] = []
    private var selectedIndex: Int = 0

    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private var instructionLabel = NSTextField(labelWithString: "")

    var onJump: ((SpaceRecord) -> String?)?

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Space Names"
        window.isFloatingPanel = true
        window.level = .floating
        window.titlebarAppearsTransparent = true
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        searchField.placeholderString = "Filter Spaces"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setAccessibilityLabel("Filter Spaces by name")

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Space"
        column.width = 400
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelection)
        tableView.style = .inset
        tableView.setAccessibilityLabel("Space list")
        tableView.allowsEmptySelection = false

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        instructionLabel.font = NSFont.systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.stringValue = "↑↓ select · Enter jump · Esc close"
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(searchField)
        content.addSubview(scrollView)
        content.addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 40),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: instructionLabel.topAnchor, constant: -8),

            instructionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            instructionLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }
    }

    func present(spaces: [SpaceRecord]) {
        allRecords = spaces
        applyFilter()
        searchField.stringValue = ""
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(searchField)
    }

    private func applyFilter() {
        filtered = SpaceFilter.filter(allRecords, query: searchField.stringValue)
        selectedIndex = 0
        tableView.reloadData()
        if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filtered.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
            ?? {
                let c = NSTableCellView()
                c.identifier = id
                let text = NSTextField(labelWithString: "")
                text.translatesAutoresizingMaskIntoConstraints = false
                c.addSubview(text)
                c.textField = text
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                    text.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: c.centerYAnchor)
                ])
                return c
            }()
        let record = filtered[row]
        let title = "\(record.lastSeenIndex + 1). \(record.displayName)"
        cell.textField?.stringValue = title
        cell.textField?.setAccessibilityLabel(title)
        return cell
    }

    @objc private func activateSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let record = filtered[row]
        if let message = onJump?(record) {
            instructionLabel.stringValue = message
            instructionLabel.textColor = .systemOrange
        } else {
            close()
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        switch event.keyCode {
        case 125: // down
            moveSelection(1)
            return nil
        case 126: // up
            moveSelection(-1)
            return nil
        case 36: // return
            activateSelection()
            return nil
        case 53: // escape
            close()
            return nil
        default:
            return event
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selectedIndex = max(0, min(filtered.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }
}
