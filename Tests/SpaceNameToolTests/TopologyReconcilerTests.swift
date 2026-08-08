//
//  TopologyReconcilerTests.swift
//  SpaceNameToolTests
//

import XCTest
@testable import SpaceNameToolCore

final class TopologyReconcilerTests: XCTestCase {
    private let displayA = DisplayID(
        cgDirectDisplayID: 1,
        uuidString: "AAAA-AAAA",
        localizedName: "Main"
    )

    func testMatchByManagedSpaceIDPreservesCustomNameAcrossReorder() {
        var next = 10
        let stored = [
            SpaceRecord(
                persistentID: "p1",
                managedSpaceID: 100,
                display: displayA,
                creationOrder: 1,
                customName: "Terminal",
                lastSeenIndex: 0,
                lastSeenAt: Date()
            ),
            SpaceRecord(
                persistentID: "p2",
                managedSpaceID: 200,
                display: displayA,
                creationOrder: 2,
                customName: "Browser",
                lastSeenIndex: 1,
                lastSeenAt: Date()
            )
        ]
        // Reordered live: 200 first, then 100.
        let live = [
            LiveSpaceNode(managedSpaceID: 200, index: 0, display: displayA),
            LiveSpaceNode(managedSpaceID: 100, index: 1, display: displayA)
        ]

        let diff = TopologyReconciler.reconcile(
            live: live,
            stored: stored,
            now: Date(),
            nextCreationOrder: &next
        )

        XCTAssertEqual(diff.newlyCreated.count, 0)
        XCTAssertEqual(diff.activeRecords.count, 2)
        let terminal = diff.activeRecords.first { $0.persistentID == "p1" }
        let browser = diff.activeRecords.first { $0.persistentID == "p2" }
        XCTAssertEqual(terminal?.customName, "Terminal")
        XCTAssertEqual(terminal?.lastSeenIndex, 1)
        XCTAssertEqual(browser?.customName, "Browser")
        XCTAssertEqual(browser?.lastSeenIndex, 0)
        XCTAssertEqual(next, 10)
    }

    func testInsertSpaceInMiddleCreatesOnlyOneNewRecord() {
        var next = 3
        let stored = [
            SpaceRecord(
                persistentID: "p1",
                managedSpaceID: 100,
                display: displayA,
                creationOrder: 1,
                customName: "One",
                lastSeenIndex: 0,
                lastSeenAt: Date()
            ),
            SpaceRecord(
                persistentID: "p2",
                managedSpaceID: 200,
                display: displayA,
                creationOrder: 2,
                customName: "Two",
                lastSeenIndex: 1,
                lastSeenAt: Date()
            )
        ]
        let live = [
            LiveSpaceNode(managedSpaceID: 100, index: 0, display: displayA),
            LiveSpaceNode(managedSpaceID: 300, index: 1, display: displayA),
            LiveSpaceNode(managedSpaceID: 200, index: 2, display: displayA)
        ]

        let diff = TopologyReconciler.reconcile(
            live: live,
            stored: stored,
            now: Date(),
            nextCreationOrder: &next
        )

        XCTAssertEqual(diff.newlyCreated.count, 1)
        XCTAssertEqual(diff.newlyCreated.first?.managedSpaceID, 300)
        XCTAssertEqual(diff.activeRecords.count, 3)
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "p1" }?.customName, "One")
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "p2" }?.customName, "Two")
        XCTAssertEqual(next, 4)
    }

    func testFallbackKeyingWithoutManagedIDsUsesCreationOrder() {
        var next = 3
        let stored = [
            SpaceRecord(
                persistentID: "p1",
                managedSpaceID: nil,
                display: displayA,
                creationOrder: 1,
                customName: "First",
                lastSeenIndex: 0,
                lastSeenAt: Date()
            ),
            SpaceRecord(
                persistentID: "p2",
                managedSpaceID: nil,
                display: displayA,
                creationOrder: 2,
                customName: "Second",
                lastSeenIndex: 1,
                lastSeenAt: Date()
            )
        ]
        let live = [
            LiveSpaceNode(managedSpaceID: nil, index: 0, display: displayA),
            LiveSpaceNode(managedSpaceID: nil, index: 1, display: displayA)
        ]

        let diff = TopologyReconciler.reconcile(
            live: live,
            stored: stored,
            now: Date(),
            nextCreationOrder: &next
        )

        XCTAssertEqual(diff.newlyCreated.count, 0)
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "p1" }?.customName, "First")
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "p2" }?.customName, "Second")
    }

    func testUnmatchedStoredArchivesAfterSevenDays() {
        var next = 5
        let old = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        let stored = [
            SpaceRecord(
                persistentID: "keep",
                managedSpaceID: 100,
                display: displayA,
                creationOrder: 1,
                customName: "Keep",
                lastSeenIndex: 0,
                lastSeenAt: Date()
            ),
            SpaceRecord(
                persistentID: "gone",
                managedSpaceID: 999,
                display: displayA,
                creationOrder: 2,
                customName: "ArchivedSoon",
                lastSeenIndex: 1,
                lastSeenAt: old
            )
        ]
        let live = [
            LiveSpaceNode(managedSpaceID: 100, index: 0, display: displayA)
        ]

        let diff = TopologyReconciler.reconcile(
            live: live,
            stored: stored,
            now: Date(),
            nextCreationOrder: &next
        )

        XCTAssertEqual(diff.activeRecords.count, 1)
        XCTAssertEqual(diff.activeRecords.first?.persistentID, "keep")
        XCTAssertTrue(diff.archivedRecords.contains { $0.persistentID == "gone" && $0.archived })
        XCTAssertEqual(diff.archivedRecords.first { $0.persistentID == "gone" }?.customName, "ArchivedSoon")
    }

    func testUnmatchedStoredStaysActiveWithinSevenDays() {
        var next = 5
        let recent = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let stored = [
            SpaceRecord(
                persistentID: "keep",
                managedSpaceID: 100,
                display: displayA,
                creationOrder: 1,
                customName: "Keep",
                lastSeenIndex: 0,
                lastSeenAt: Date()
            ),
            SpaceRecord(
                persistentID: "temp-gone",
                managedSpaceID: 999,
                display: displayA,
                creationOrder: 2,
                customName: "Hold",
                lastSeenIndex: 1,
                lastSeenAt: recent
            )
        ]
        let live = [
            LiveSpaceNode(managedSpaceID: 100, index: 0, display: displayA)
        ]

        let diff = TopologyReconciler.reconcile(
            live: live,
            stored: stored,
            now: Date(),
            nextCreationOrder: &next
        )

        XCTAssertEqual(diff.unmatchedPreviouslyActive.count, 1)
        XCTAssertEqual(diff.unmatchedPreviouslyActive.first?.customName, "Hold")
        XCTAssertFalse(diff.archivedRecords.contains { $0.persistentID == "temp-gone" })
    }
}
