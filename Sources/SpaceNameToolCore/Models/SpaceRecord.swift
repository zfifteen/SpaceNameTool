//
//  SpaceRecord.swift
//  SpaceNameToolCore
//
//  Durable Space identity + user name (tech spec §2).
//

import Foundation

/// One virtual desktop as stored by NameStore.
public struct SpaceRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Our durable UUID, assigned when first seen.
    public var persistentID: String

    /// From CGS `ManagedSpaceID` / `id64` when available.
    public var managedSpaceID: UInt64?

    public var display: DisplayID

    /// Monotonic counter assigned on first sight; never reused for keying fallback.
    public var creationOrder: Int

    public var customName: String

    /// Last observed Mission Control index on that display (ephemeral).
    public var lastSeenIndex: Int

    public var lastSeenAt: Date

    /// Soft-deleted topology survivors (FR-6); not shown as active.
    public var archived: Bool

    public var id: String { persistentID }

    public init(
        persistentID: String = UUID().uuidString,
        managedSpaceID: UInt64? = nil,
        display: DisplayID,
        creationOrder: Int,
        customName: String = "",
        lastSeenIndex: Int = 0,
        lastSeenAt: Date = Date(),
        archived: Bool = false
    ) {
        self.persistentID = persistentID
        self.managedSpaceID = managedSpaceID
        self.display = display
        self.creationOrder = creationOrder
        self.customName = customName
        self.lastSeenIndex = lastSeenIndex
        self.lastSeenAt = lastSeenAt
        self.archived = archived
    }

    /// UI label: custom name if non-empty, otherwise "Desktop N" (1-based index).
    public var displayName: String {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "Desktop \(lastSeenIndex + 1)"
    }
}

/// A Space observed on the live system (not yet durable).
public struct LiveSpaceNode: Equatable, Sendable {
    public var managedSpaceID: UInt64?
    public var index: Int
    public var display: DisplayID
    public var spaceUUID: String?

    public init(
        managedSpaceID: UInt64? = nil,
        index: Int,
        display: DisplayID,
        spaceUUID: String? = nil
    ) {
        self.managedSpaceID = managedSpaceID
        self.index = index
        self.display = display
        self.spaceUUID = spaceUUID
    }
}

/// Result of reconciling live topology with stored records.
public struct TopologyDiffResult: Equatable, Sendable {
    /// Active (non-archived) records after reconcile, sorted by display then index.
    public var activeRecords: [SpaceRecord]

    /// Still archived after this pass.
    public var archivedRecords: [SpaceRecord]

    /// Live nodes that created brand-new records this pass.
    public var newlyCreated: [SpaceRecord]

    /// Stored actives that went unmatched this pass (candidates for archive later).
    public var unmatchedPreviouslyActive: [SpaceRecord]

    public init(
        activeRecords: [SpaceRecord] = [],
        archivedRecords: [SpaceRecord] = [],
        newlyCreated: [SpaceRecord] = [],
        unmatchedPreviouslyActive: [SpaceRecord] = []
    ) {
        self.activeRecords = activeRecords
        self.archivedRecords = archivedRecords
        self.newlyCreated = newlyCreated
        self.unmatchedPreviouslyActive = unmatchedPreviouslyActive
    }
}
