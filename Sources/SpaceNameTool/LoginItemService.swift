//
//  LoginItemService.swift
//  SpaceNameTool
//
//  SMAppService login item (NFR-2). No LaunchDaemon, no privileged helper.
//

import Foundation
import ServiceManagement

enum LoginItemService {
    /// Current registration status for the main app login item.
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    /// Registers or unregisters launch-at-login.
    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> SMAppService.Status {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        return SMAppService.mainApp.status
    }

    static var statusDescription: String {
        switch status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Not registered"
        case .notFound: return "Not found (package as .app for reliable login items)"
        case .requiresApproval: return "Requires approval in System Settings → General → Login Items"
        @unknown default: return "Unknown"
        }
    }
}
