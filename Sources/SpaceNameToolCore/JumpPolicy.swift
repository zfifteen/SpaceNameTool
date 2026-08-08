//
//  JumpPolicy.swift
//  SpaceNameToolCore
//
//  Pure decision tree for SIP-safe Space jumping (tech spec §4.4).
//  No injection; fail closed to user instruction.
//

import Foundation

/// Capabilities available on the host for Space jumping.
public struct JumpCapabilities: Equatable, Sendable {
    public var cgsSetActiveSpaceAvailable: Bool
    public var accessibilityTrusted: Bool

    public init(cgsSetActiveSpaceAvailable: Bool, accessibilityTrusted: Bool) {
        self.cgsSetActiveSpaceAvailable = cgsSetActiveSpaceAvailable
        self.accessibilityTrusted = accessibilityTrusted
    }
}

/// Chosen jump strategy for a target Space.
public enum JumpStrategy: Equatable, Sendable {
    /// Attempt private CGS setter in-process (full SIP retained).
    case cgsSetActiveSpace(spaceID: UInt64)
    /// Synthesize Ctrl+Number (1-9) via CGEvent; needs Accessibility.
    case controlNumberKey(number: Int)
    /// Show instruction only; user switches manually.
    case instructUser(message: String)
}

public enum JumpPolicy {
    /// Selects the first viable strategy for `record` under `capabilities`.
    public static func strategy(
        for record: SpaceRecord,
        capabilities: JumpCapabilities
    ) -> JumpStrategy {
        if capabilities.cgsSetActiveSpaceAvailable, let mid = record.managedSpaceID {
            return .cgsSetActiveSpace(spaceID: mid)
        }

        let oneBased = record.lastSeenIndex + 1
        if capabilities.accessibilityTrusted, (1...9).contains(oneBased) {
            return .controlNumberKey(number: oneBased)
        }

        let name = record.displayName
        if (1...9).contains(oneBased) {
            return .instructUser(
                message: "Press Control+\(oneBased) to switch to “\(name)”."
            )
        }
        return .instructUser(
            message: "Switch to “\(name)” with Control+Arrow or Mission Control (index \(oneBased))."
        )
    }
}

/// Filters Space records by a case-insensitive substring of displayName.
public enum SpaceFilter {
    public static func filter(_ records: [SpaceRecord], query: String) -> [SpaceRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return records }
        return records.filter {
            $0.displayName.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
