//
//  PreferencesStore.swift
//  SpaceNameTool
//
//  UserDefaults-backed preferences (overlay, login item, hotkey).
//

import Combine
import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    private let defaults: UserDefaults

    @Published var overlayEnabled: Bool {
        didSet { defaults.set(overlayEnabled, forKey: Keys.overlayEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var showIndexInMenuBar: Bool {
        didSet { defaults.set(showIndexInMenuBar, forKey: Keys.showIndexInMenuBar) }
    }

    /// Carbon virtual key for switcher (default Space = 0x31) with Control.
    @Published var switcherHotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(switcherHotkeyKeyCode), forKey: Keys.switcherHotkeyKeyCode) }
    }

    private enum Keys {
        static let overlayEnabled = "overlayEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let showIndexInMenuBar = "showIndexInMenuBar"
        static let switcherHotkeyKeyCode = "switcherHotkeyKeyCode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.overlayEnabled) == nil {
            defaults.set(true, forKey: Keys.overlayEnabled)
        }
        self.overlayEnabled = defaults.bool(forKey: Keys.overlayEnabled)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showIndexInMenuBar = defaults.bool(forKey: Keys.showIndexInMenuBar)
        let code = defaults.object(forKey: Keys.switcherHotkeyKeyCode) as? Int ?? 0x31
        self.switcherHotkeyKeyCode = UInt32(code)
    }
}
