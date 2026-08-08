import XCTest
@testable import SpaceNameToolCore

final class ActiveResolutionTests: XCTestCase {
    func testResolveByManagedID() {
        let d = DisplayID(cgDirectDisplayID: 1, uuidString: "A", localizedName: "Main")
        let records = [
            SpaceRecord(persistentID: "a", managedSpaceID: 1, display: d, creationOrder: 1, lastSeenIndex: 0),
            SpaceRecord(persistentID: "b", managedSpaceID: 2, display: d, creationOrder: 2, lastSeenIndex: 1)
        ]
        let active = SpaceMonitor.resolveActiveRecord(activeManaged: 2, activeRecords: records)
        XCTAssertEqual(active?.persistentID, "b")
    }

    func testResolveFallbackFirstSortedIndex() {
        let d = DisplayID(cgDirectDisplayID: 1, uuidString: "A", localizedName: "Main")
        let records = [
            SpaceRecord(persistentID: "b", managedSpaceID: 2, display: d, creationOrder: 2, lastSeenIndex: 1),
            SpaceRecord(persistentID: "a", managedSpaceID: 1, display: d, creationOrder: 1, lastSeenIndex: 0)
        ]
        let active = SpaceMonitor.resolveActiveRecord(activeManaged: nil, activeRecords: records)
        XCTAssertEqual(active?.persistentID, "a")
    }
}
