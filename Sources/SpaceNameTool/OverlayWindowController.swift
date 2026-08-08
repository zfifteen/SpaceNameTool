//
//  OverlayWindowController.swift
//  SpaceNameTool
//
//  Heads-Up bezel (FR-3) — deferred until NameStore + SpaceMonitor + menu bar work.
//  Mission Control text replacement is intentionally closed (requirements non-goal).
//

import AppKit
import SpaceNameToolCore

/// Floating overlay for Space name display after a switch.
final class OverlayWindowController: NSWindowController {
    // TODO(priority-4): NSPanel nonactivatingPanel, level screenSaver-1, 1.5s fade.
    // Do not implement until menu bar naming path is verified on device.

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        window.ignoresMouseEvents = true
        self.init(window: window)
    }

    func present(for space: SpaceRecord) {
        _ = space
        // Stub: product overlay lands after core path works.
    }

    func dismiss() {
        close()
    }
}
