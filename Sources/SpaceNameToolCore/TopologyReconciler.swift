//
//  TopologyReconciler.swift
//  SpaceNameToolCore
//
//  Diff live Spaces against stored records (tech spec §2).
//  Never keys solely by array index.
//

import Foundation

public enum TopologyReconciler {
    /// Days without a match before an unmatched record is archived (tech spec §2).
    public static let archiveAfterDays: Double = 7

    /// Reconcile live topology with stored records.
    ///
    /// Matching preference:
    /// 1. `managedSpaceID` when both sides have it
    /// 2. Per-display order among remaining (stable by `creationOrder` vs live index)
    /// 3. Neighbor-preservation pass for leftovers
    ///
    /// New live spaces get a fresh `persistentID` and a new `creationOrder`.
    /// Unmatched stored records keep their names; after `archiveAfterDays` without
    /// a sighting they move to archive (not hard-deleted).
    public static func reconcile(
        live: [LiveSpaceNode],
        stored: [SpaceRecord],
        now: Date = Date(),
        nextCreationOrder: inout Int
    ) -> TopologyDiffResult {
        let activeStored = stored.filter { !$0.archived }
        var archived = stored.filter { $0.archived }

        var matchedLiveIndices = Set<Int>()
        var matchedStoredIDs = Set<String>()
        var updatedByPersistentID: [String: SpaceRecord] = [:]

        // --- Pass 0: revive archived by ManagedSpaceID (FR-6 name survival) ---
        for (liveIndex, node) in live.enumerated() {
            guard let mid = node.managedSpaceID else { continue }
            guard let archIndex = archived.firstIndex(where: {
                !matchedStoredIDs.contains($0.persistentID) && $0.managedSpaceID == mid
            }) else { continue }
            var record = archived.remove(at: archIndex)
            record = touch(record, with: node, now: now)
            updatedByPersistentID[record.persistentID] = record
            matchedLiveIndices.insert(liveIndex)
            matchedStoredIDs.insert(record.persistentID)
        }

        // --- Pass 1: ManagedSpaceID among active ---
        for (liveIndex, node) in live.enumerated() {
            guard !matchedLiveIndices.contains(liveIndex) else { continue }
            guard let mid = node.managedSpaceID else { continue }
            guard let storedIndex = activeStored.firstIndex(where: {
                !matchedStoredIDs.contains($0.persistentID) && $0.managedSpaceID == mid
            }) else { continue }

            var record = activeStored[storedIndex]
            record = touch(record, with: node, now: now)
            updatedByPersistentID[record.persistentID] = record
            matchedLiveIndices.insert(liveIndex)
            matchedStoredIDs.insert(record.persistentID)
        }

        // --- Pass 2: per-display positional match on remaining ---
        let liveByDisplay = Dictionary(grouping: Array(live.enumerated())) { pair in
            displayKey(pair.element.display)
        }

        for (_, livePairs) in liveByDisplay {
            let unmatchedLive = livePairs
                .filter { !matchedLiveIndices.contains($0.offset) }
                .sorted { $0.element.index < $1.element.index }

            guard let firstDisplay = unmatchedLive.first?.element.display else { continue }

            let unmatchedStoredOnDisplay = activeStored
                .filter {
                    !matchedStoredIDs.contains($0.persistentID)
                        && $0.display.matchesForKeying(firstDisplay)
                }
                .sorted { $0.creationOrder < $1.creationOrder }

            let pairCount = min(unmatchedLive.count, unmatchedStoredOnDisplay.count)
            for i in 0..<pairCount {
                let (liveIndex, node) = unmatchedLive[i]
                var record = unmatchedStoredOnDisplay[i]
                if record.managedSpaceID == nil, let mid = node.managedSpaceID {
                    record.managedSpaceID = mid
                }
                record = touch(record, with: node, now: now)
                updatedByPersistentID[record.persistentID] = record
                matchedLiveIndices.insert(liveIndex)
                matchedStoredIDs.insert(record.persistentID)
            }
        }

        // --- Pass 3: neighbor-preservation for remaining unmatched live ---
        // For each unmatched live node, prefer a stored record on the same display
        // whose lastSeenIndex is closest to the live index among still-free records.
        for (liveIndex, node) in live.enumerated() where !matchedLiveIndices.contains(liveIndex) {
            let candidates = activeStored.filter {
                !matchedStoredIDs.contains($0.persistentID)
                    && $0.display.matchesForKeying(node.display)
            }
            guard let best = candidates.min(by: {
                abs($0.lastSeenIndex - node.index) < abs($1.lastSeenIndex - node.index)
            }) else { continue }

            // Only accept neighbor match if index distance is small (heuristic).
            if abs(best.lastSeenIndex - node.index) > 1 {
                continue
            }

            var record = best
            if record.managedSpaceID == nil, let mid = node.managedSpaceID {
                record.managedSpaceID = mid
            }
            record = touch(record, with: node, now: now)
            updatedByPersistentID[record.persistentID] = record
            matchedLiveIndices.insert(liveIndex)
            matchedStoredIDs.insert(record.persistentID)
        }

        // --- Create records for still-unmatched live spaces ---
        var newlyCreated: [SpaceRecord] = []
        for (liveIndex, node) in live.enumerated() where !matchedLiveIndices.contains(liveIndex) {
            let order = nextCreationOrder
            nextCreationOrder += 1
            let record = SpaceRecord(
                managedSpaceID: node.managedSpaceID,
                display: node.display,
                creationOrder: order,
                customName: "",
                lastSeenIndex: node.index,
                lastSeenAt: now,
                archived: false
            )
            newlyCreated.append(record)
            updatedByPersistentID[record.persistentID] = record
            matchedLiveIndices.insert(liveIndex)
            matchedStoredIDs.insert(record.persistentID)
        }

        // --- Unmatched stored: keep or archive ---
        var unmatchedPreviouslyActive: [SpaceRecord] = []
        let archiveCutoff = now.addingTimeInterval(-archiveAfterDays * 24 * 60 * 60)

        for record in activeStored where !matchedStoredIDs.contains(record.persistentID) {
            var orphan = record
            if orphan.lastSeenAt < archiveCutoff {
                orphan.archived = true
                archived.append(orphan)
            } else {
                unmatchedPreviouslyActive.append(orphan)
                updatedByPersistentID[orphan.persistentID] = orphan
            }
        }

        // Keep older archives as-is (unless we revived one — we do not auto-revive by ID here).
        let activeRecords = updatedByPersistentID.values
            .filter { !$0.archived }
            .sorted { lhs, rhs in
                if lhs.display.cgDirectDisplayID != rhs.display.cgDirectDisplayID {
                    return lhs.display.cgDirectDisplayID < rhs.display.cgDirectDisplayID
                }
                return lhs.lastSeenIndex < rhs.lastSeenIndex
            }

        return TopologyDiffResult(
            activeRecords: activeRecords,
            archivedRecords: archived,
            newlyCreated: newlyCreated,
            unmatchedPreviouslyActive: unmatchedPreviouslyActive
        )
    }

    private static func touch(_ record: SpaceRecord, with node: LiveSpaceNode, now: Date) -> SpaceRecord {
        var copy = record
        copy.lastSeenIndex = node.index
        copy.lastSeenAt = now
        copy.archived = false
        // Refresh display metadata when UUID becomes known.
        if copy.display.uuidString == nil, let uuid = node.display.uuidString {
            copy.display.uuidString = uuid
        }
        if !node.display.localizedName.isEmpty,
           node.display.localizedName != "Display" {
            copy.display.localizedName = node.display.localizedName
        }
        copy.display.cgDirectDisplayID = node.display.cgDirectDisplayID
        if let mid = node.managedSpaceID {
            copy.managedSpaceID = mid
        }
        return copy
    }

    private static func displayKey(_ display: DisplayID) -> String {
        if let uuid = display.uuidString, !uuid.isEmpty {
            return "uuid:\(uuid)"
        }
        return "cg:\(display.cgDirectDisplayID)"
    }
}
