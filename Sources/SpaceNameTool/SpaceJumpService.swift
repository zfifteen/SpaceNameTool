//
//  SpaceJumpService.swift
//  SpaceNameTool
//
//  SIP-safe Space jump ladder (tech spec §4.4). In-process only.
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
    @discardableResult
    static func jump(to record: SpaceRecord) -> String? {
        let strategy = JumpPolicy.strategy(for: record, capabilities: currentCapabilities())
        switch strategy {
        case .cgsSetActiveSpace(let spaceID):
            switch CGSPrivate.setActiveSpace(spaceID) {
            case .success:
                return nil
            case .failure:
                // Fall through ladder manually.
                return jumpWithoutCGS(record: record)
            }
        case .controlNumberKey(let number):
            return postControlNumber(number) ? nil : JumpPolicy.strategy(
                for: record,
                capabilities: JumpCapabilities(
                    cgsSetActiveSpaceAvailable: false,
                    accessibilityTrusted: false
                )
            ).instructionMessage
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
            return postControlNumber(number) ? nil : JumpPolicy.strategy(
                for: record,
                capabilities: JumpCapabilities(
                    cgsSetActiveSpaceAvailable: false,
                    accessibilityTrusted: false
                )
            ).instructionMessage
        case .instructUser(let message):
            return message
        case .cgsSetActiveSpace:
            return nil
        }
    }

    private static func postControlNumber(_ number: Int) -> Bool {
        guard (1...9).contains(number) else { return false }
        // kVK_ANSI_1 = 0x12 ... ANSI_9 = 0x19 (not sequential for 0); map carefully.
        let keyCodes: [Int: CGKeyCode] = [
            1: 0x12, 2: 0x13, 3: 0x14, 4: 0x15, 5: 0x17,
            6: 0x16, 7: 0x1A, 8: 0x1C, 9: 0x19
        ]
        guard let keyCode = keyCodes[number] else { return false }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }
        down.flags = .maskControl
        up.flags = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    static func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}

private extension JumpStrategy {
    var instructionMessage: String? {
        if case .instructUser(let message) = self { return message }
        return nil
    }
}
