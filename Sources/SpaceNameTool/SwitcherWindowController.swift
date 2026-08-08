//
//  SwitcherWindowController.swift
//  SpaceNameTool
//
//  Custom switcher palette (FR-4) — deferred until core naming path works.
//  Jumping Spaces (if added later) must stay SIP-safe; no Dock injection.
//

import AppKit
import SpaceNameToolCore

/// Spotlight-like list of named Spaces.
final class SwitcherWindowController: NSWindowController {
    // TODO(priority-4): search field, arrow navigation, optional CGSSetActiveSpace / Ctrl+Number.

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Space Names"
        self.init(window: window)
    }

    func present(spaces: [SpaceRecord]) {
        _ = spaces
    }
}
