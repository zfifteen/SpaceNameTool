//
//  SpaceJumpService.swift
//  SpaceNameTool
//
//  SIP-safe Space jump ladder (tech spec §4.4). In-process only.
//
//  Important: CGS switch symbols often exist but no-op for third-party apps.
//  Callers must treat “symbol present” as attempt-only; we verify with
//  CGSGetActiveSpace and fall through to Control+Number / instruction UI.
//

import AppKit
import ApplicationServices
import SpaceNameToolCore

enum SpaceJumpService {
    static func currentCapabilities() -> JumpCapabilities {
        JumpCapabilities(
            cgsSetActiveSpaceAvailable: CGSPrivate.isSetActiveSpaceAvailable,
            accessibilityTrusted: AXIsProcessTrusted()
        )
    }

    /// Attempts to jump using JumpPolicy; returns user-facing message if instruction-only or failure.
    ///
    /// Prefer calling from a deferred main-queue block after a menu closes so synthetic
    /// key events are not eaten by menu tracking.
    @discardableResult
    static func jump(to record: SpaceRecord) -> String? {
        let strategy = JumpPolicy.strategy(for: record, capabilities: currentCapabilities())
        switch strategy {
        case .cgsSetActiveSpace(let spaceID):
            let displayUUID = record.display.uuidString
            switch CGSPrivate.setActiveSpace(spaceID, displayUUID: displayUUID) {
            case .success:
                return nil
            case .failure:
                return jumpWithoutCGS(record: record)
            }
        case .controlNumberKey(let number):
            if postControlNumber(number) {
                return nil
            }
            return instruction(for: record)
        case .instructUser(let message):
            return message
        }
    }

    private static func jumpWithoutCGS(record: SpaceRecord) -> String? {
        let caps = JumpCapabilities(
            cgsSetActiveSpaceAvailable: false,
            accessibilityTrusted: AXIsProcessTrusted()
        )
        switch JumpPolicy.strategy(for: record, capabilities: caps) {
        case .controlNumberKey(let number):
            if postControlNumber(number) {
                return nil
            }
            return instruction(for: record)
        case .instructUser(let message):
            return message
        case .cgsSetActiveSpace:
            return instruction(for: record)
        }
    }

    private static func instruction(for record: SpaceRecord) -> String {
        let oneBased = record.lastSeenIndex + 1
        let name = record.displayName
        if (1...9).contains(oneBased) {
            var message = "Press Control+\(oneBased) to switch to “\(name)”."
            if !AXIsProcessTrusted() {
                message += "\n\nIf that shortcut does nothing, enable it in System Settings → Keyboard → Keyboard Shortcuts → Mission Control, and grant Accessibility to SpaceNameTool."
            } else {
                message += "\n\nIf the shortcut does nothing, enable “Switch to Desktop \(oneBased)” in System Settings → Keyboard → Keyboard Shortcuts → Mission Control."
            }
            return message
        }
        return "Switch to “\(name)” with Control+Arrow or Mission Control (index \(oneBased))."
    }

    /// Posts Control+digit using the session event tap (more reliable after menu dismissal).
    /// Returns whether events were posted while Accessibility is trusted (not whether the Space changed).
    private static func postControlNumber(_ number: Int) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard (1...9).contains(number) else { return false }

        // kVK_ANSI_1 … kVK_ANSI_9 (not sequential for all digits).
        let keyCodes: [Int: CGKeyCode] = [
            1: 0x12, 2: 0x13, 3: 0x14, 4: 0x15, 5: 0x17,
            6: 0x16, 7: 0x1A, 8: 0x1C, 9: 0x19
        ]
        guard let keyCode = keyCodes[number] else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }
        down.flags = .maskControl
        up.flags = .maskControl

        // Prefer session tap; also try HID tap if session posts silently fail on some builds.
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    static func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
