import XCTest
@testable import SpaceNameToolCore

final class JumpPolicyTests: XCTestCase {
    private let display = DisplayID(cgDirectDisplayID: 1, uuidString: "U", localizedName: "Main")

    private func record(index: Int, mid: UInt64? = 10, name: String = "Term") -> SpaceRecord {
        SpaceRecord(
            managedSpaceID: mid,
            display: display,
            creationOrder: index + 1,
            customName: name,
            lastSeenIndex: index
        )
    }

    func testPrefersCGSWhenAvailable() {
        let s = JumpPolicy.strategy(
            for: record(index: 1),
            capabilities: JumpCapabilities(cgsSetActiveSpaceAvailable: true, accessibilityTrusted: true)
        )
        XCTAssertEqual(s, .cgsSetActiveSpace(spaceID: 10))
    }

    func testFallsBackToControlNumber() {
        let s = JumpPolicy.strategy(
            for: record(index: 2),
            capabilities: JumpCapabilities(cgsSetActiveSpaceAvailable: false, accessibilityTrusted: true)
        )
        XCTAssertEqual(s, .controlNumberKey(number: 3))
    }

    func testInstructsWhenNoAX() {
        let s = JumpPolicy.strategy(
            for: record(index: 0, name: "Home"),
            capabilities: JumpCapabilities(cgsSetActiveSpaceAvailable: false, accessibilityTrusted: false)
        )
        if case .instructUser(let msg) = s {
            XCTAssertTrue(msg.contains("Control+1"))
            XCTAssertTrue(msg.contains("Home"))
        } else {
            XCTFail("Expected instructUser")
        }
    }

    func testHighIndexInstructsWithoutControlNumber() {
        let s = JumpPolicy.strategy(
            for: record(index: 12, mid: nil),
            capabilities: JumpCapabilities(cgsSetActiveSpaceAvailable: false, accessibilityTrusted: true)
        )
        if case .instructUser = s {
            // ok
        } else {
            XCTFail("Index 13 has no Ctrl+Number mapping")
        }
    }

    func testSpaceFilter() {
        let records = [
            record(index: 0, name: "Terminal"),
            record(index: 1, name: "Browser"),
            record(index: 2, name: "term notes")
        ]
        let filtered = SpaceFilter.filter(records, query: "term")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(SpaceFilter.filter(records, query: "  ").count, 3)
    }
}
