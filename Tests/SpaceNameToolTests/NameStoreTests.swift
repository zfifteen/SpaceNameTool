//
//  NameStoreTests.swift
//  SpaceNameToolTests
//

import XCTest
@testable import SpaceNameToolCore

final class NameStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceNameToolTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSanitizeAndPersistCustomName() throws {
        let store = NameStore(directoryURL: tempDir)
        let display = DisplayID(cgDirectDisplayID: 1, uuidString: "U1", localizedName: "Main")
        let live = [LiveSpaceNode(managedSpaceID: 42, index: 0, display: display)]
        let diff = store.applyLiveTopology(live)
        XCTAssertEqual(diff.activeRecords.count, 1)
        let id = diff.activeRecords[0].persistentID

        store.setCustomName("  Terminal\u{0007}  ", persistentID: id)
        XCTAssertEqual(store.record(persistentID: id)?.customName, "Terminal")
        XCTAssertEqual(store.displayName(forManagedSpaceID: 42), "Terminal")

        // Reload from disk.
        let reloaded = NameStore(directoryURL: tempDir)
        XCTAssertEqual(reloaded.record(managedSpaceID: 42)?.customName, "Terminal")
    }

    func testExportImportJSON() throws {
        let store = NameStore(directoryURL: tempDir)
        let display = DisplayID(cgDirectDisplayID: 1, uuidString: "U1", localizedName: "Main")
        _ = store.applyLiveTopology([
            LiveSpaceNode(managedSpaceID: 1, index: 0, display: display)
        ])
        if let id = store.allRecords().first?.persistentID {
            store.setCustomName("Code", persistentID: id)
        }

        let data = try store.exportJSON()
        let otherDir = tempDir.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
        let other = NameStore(directoryURL: otherDir)
        try other.importJSON(data, replace: true)
        XCTAssertEqual(other.allRecords().first?.customName, "Code")
    }

    func testResetAllNames() {
        let store = NameStore(directoryURL: tempDir)
        let display = DisplayID(cgDirectDisplayID: 1, uuidString: "U1", localizedName: "Main")
        let diff = store.applyLiveTopology([
            LiveSpaceNode(managedSpaceID: 7, index: 0, display: display)
        ])
        store.setCustomName("X", persistentID: diff.activeRecords[0].persistentID)
        store.resetAllNames()
        XCTAssertEqual(store.allRecords().first?.customName, "")
        XCTAssertEqual(store.allRecords().first?.displayName, "Desktop 1")
    }

    func testConcurrentSetNameIsSafe() {
        let store = NameStore(directoryURL: tempDir)
        let display = DisplayID(cgDirectDisplayID: 1, uuidString: "U1", localizedName: "Main")
        let diff = store.applyLiveTopology([
            LiveSpaceNode(managedSpaceID: 1, index: 0, display: display),
            LiveSpaceNode(managedSpaceID: 2, index: 1, display: display)
        ])
        let ids = diff.activeRecords.map(\.persistentID)
        let group = DispatchGroup()
        for (i, id) in ids.enumerated() {
            group.enter()
            DispatchQueue.global().async {
                store.setCustomName("N\(i)", persistentID: id)
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(store.allRecords().count, 2)
    }

    func testCorruptPlistDoesNotCrash() throws {
        let plist = tempDir.appendingPathComponent(NameStore.plistFileName)
        try Data("%not-plist%".utf8).write(to: plist)
        let store = NameStore(directoryURL: tempDir)
        XCTAssertTrue(store.allRecords().isEmpty)
    }
}
