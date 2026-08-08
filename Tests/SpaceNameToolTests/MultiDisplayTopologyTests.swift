import XCTest
@testable import SpaceNameToolCore

final class MultiDisplayTopologyTests: XCTestCase {
    func testTwoDisplaysKeepNamesIndependent() {
        var next = 10
        let d1 = DisplayID(cgDirectDisplayID: 1, uuidString: "D1", localizedName: "Main")
        let d2 = DisplayID(cgDirectDisplayID: 2, uuidString: "D2", localizedName: "Dell")
        let stored = [
            SpaceRecord(persistentID: "m1", managedSpaceID: 100, display: d1, creationOrder: 1, customName: "Code", lastSeenIndex: 0, lastSeenAt: Date()),
            SpaceRecord(persistentID: "e1", managedSpaceID: 200, display: d2, creationOrder: 2, customName: "Mail", lastSeenIndex: 0, lastSeenAt: Date())
        ]
        let live = [
            LiveSpaceNode(managedSpaceID: 100, index: 0, display: d1),
            LiveSpaceNode(managedSpaceID: 200, index: 0, display: d2)
        ]
        let diff = TopologyReconciler.reconcile(live: live, stored: stored, now: Date(), nextCreationOrder: &next)
        XCTAssertEqual(diff.activeRecords.count, 2)
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "m1" }?.customName, "Code")
        XCTAssertEqual(diff.activeRecords.first { $0.persistentID == "e1" }?.customName, "Mail")
    }

    func testMassNewSpacesCreateRecords() {
        var next = 1
        let d = DisplayID(cgDirectDisplayID: 1, uuidString: "D1", localizedName: "Main")
        let live = (0..<4).map { LiveSpaceNode(managedSpaceID: UInt64(1000 + $0), index: $0, display: d) }
        let diff = TopologyReconciler.reconcile(live: live, stored: [], now: Date(), nextCreationOrder: &next)
        XCTAssertEqual(diff.newlyCreated.count, 4)
        XCTAssertEqual(diff.activeRecords.count, 4)
        XCTAssertEqual(next, 5)
    }

    func testArchiveReappearsByManagedID() {
        var next = 5
        let d = DisplayID(cgDirectDisplayID: 1, uuidString: "D1", localizedName: "Main")
        let archived = SpaceRecord(
            persistentID: "old",
            managedSpaceID: 555,
            display: d,
            creationOrder: 1,
            customName: "Back",
            lastSeenIndex: 0,
            lastSeenAt: Date().addingTimeInterval(-30 * 24 * 3600),
            archived: true
        )
        // Current reconciler does not auto-revive archives by ManagedSpaceID in pass 1
        // because it only scans activeStored. Documented behavior: archived stays archived
        // unless we re-include archives in match. Spec says archive not delete — revive is nice-to-have.
        let live = [LiveSpaceNode(managedSpaceID: 555, index: 0, display: d)]
        let diff = TopologyReconciler.reconcile(live: live, stored: [archived], now: Date(), nextCreationOrder: &next)
        // Without revive: new record OR we implement revive. Prefer revive for FR-6.
        // After remediation we expect name "Back" restored.
        let named = diff.activeRecords.first { $0.managedSpaceID == 555 }
        XCTAssertNotNil(named)
        // If revive implemented, customName is Back; if new, empty — fix reconciler to revive.
        XCTAssertEqual(named?.customName, "Back")
    }
}
