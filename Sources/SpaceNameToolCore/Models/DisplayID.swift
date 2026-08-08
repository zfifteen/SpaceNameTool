//
//  DisplayID.swift
//  SpaceNameToolCore
//
//  Stable-ish identity for a physical/logical display (tech spec §2).
//

import ColorSync
import CoreGraphics
import Foundation

/// Identifies a display for multi-Space / multi-monitor keying.
public struct DisplayID: Codable, Hashable, Sendable {
    /// `CGDirectDisplayID` at last observation (can change after reconfiguration).
    public var cgDirectDisplayID: UInt32

    /// Best-effort UUID from `CGDisplayCreateUUIDFromDisplayID`.
    public var uuidString: String?

    /// Human-readable name for UI fallback (e.g. "Built-in Retina Display").
    public var localizedName: String

    public init(
        cgDirectDisplayID: UInt32,
        uuidString: String? = nil,
        localizedName: String = "Display"
    ) {
        self.cgDirectDisplayID = cgDirectDisplayID
        self.uuidString = uuidString
        self.localizedName = localizedName
    }

    /// Builds a `DisplayID` from a live CoreGraphics display id.
    public static func from(cgDisplayID: CGDirectDisplayID) -> DisplayID {
        let uuid = Self.uuidString(for: cgDisplayID)
        let name = Self.localizedName(for: cgDisplayID) ?? "Display"
        return DisplayID(
            cgDirectDisplayID: cgDisplayID,
            uuidString: uuid,
            localizedName: name
        )
    }

    public static var main: DisplayID {
        from(cgDisplayID: CGMainDisplayID())
    }

    /// True when both sides share a UUID, or both lack UUID and share cg id.
    public func matchesForKeying(_ other: DisplayID) -> Bool {
        if let a = uuidString, let b = other.uuidString, !a.isEmpty, !b.isEmpty {
            return a == b
        }
        return cgDirectDisplayID == other.cgDirectDisplayID
    }

    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        // Optional Unmanaged<CFUUID>; takeRetainedValue owns the reference when present.
        guard let unmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let cfUUID = unmanaged.takeRetainedValue()
        return CFUUIDCreateString(nil, cfUUID) as String?
    }

    private static func localizedName(for displayID: CGDirectDisplayID) -> String? {
        // NSScreen matching is AppKit; keep Core free of AppKit here.
        // Callers may overwrite localizedName after resolving NSScreen.
        _ = displayID
        return nil
    }
}
