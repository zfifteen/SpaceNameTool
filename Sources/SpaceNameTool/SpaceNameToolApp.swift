//
//  SpaceNameToolApp.swift
//  SpaceNameTool
//
//  Menu-bar entry point. SIP-safe: no injection, no privileged helper.
//

import AppKit
import SpaceNameToolCore
import SwiftUI

@main
struct SpaceNameToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var nameStore: NameStore?
    private var spaceMonitor: SpaceMonitor?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = NameStore()
        let monitor = SpaceMonitor(nameStore: store)
        let menuBar = MenuBarController(
            nameStore: store,
            spaceMonitor: monitor,
            preferences: PreferencesStore.shared
        )

        nameStore = store
        spaceMonitor = monitor
        menuBarController = menuBar

        menuBar.installStatusItem()

        // Sync login preference if already enabled at OS level.
        if LoginItemService.isEnabled {
            PreferencesStore.shared.launchAtLogin = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.teardown()
        menuBarController = nil
        spaceMonitor = nil
        nameStore = nil
    }
}
