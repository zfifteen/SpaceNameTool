//
//  CGSParseTests.swift
//  SpaceNameToolTests
//

import XCTest
@testable import SpaceNameToolCore

final class CGSParseTests: XCTestCase {
    func testParseManagedDisplaySpacesDictionaryShape() {
        let space0: [String: Any] = [
            "ManagedSpaceID": NSNumber(value: UInt64(111)),
            "uuid": "space-uuid-1"
        ]
        let space1: [String: Any] = [
            "id64": NSNumber(value: UInt64(222))
        ]
        let display: [String: Any] = [
            "Display Identifier": "Main",
            "Spaces": [space0, space1]
        ]

        let nodes = CGSPrivate.parseManagedDisplaySpaces([display as NSDictionary])
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes[0].managedSpaceID, 111)
        XCTAssertEqual(nodes[0].index, 0)
        XCTAssertEqual(nodes[0].spaceUUID, "space-uuid-1")
        XCTAssertEqual(nodes[1].managedSpaceID, 222)
        XCTAssertEqual(nodes[1].index, 1)
    }

    func testParseMissingSpacesYieldsEmpty() {
        let display: [String: Any] = ["Display Identifier": "Main"]
        let nodes = CGSPrivate.parseManagedDisplaySpaces([display as NSDictionary])
        XCTAssertTrue(nodes.isEmpty)
    }

    func testParseLowercaseSpacesKey() {
        let space: [String: Any] = ["SpaceID": NSNumber(value: 9)]
        let display: [String: Any] = [
            "Display Identifier": "AABB",
            "spaces": [space]
        ]
        let nodes = CGSPrivate.parseManagedDisplaySpaces([display as NSDictionary])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].managedSpaceID, 9)
    }
}
