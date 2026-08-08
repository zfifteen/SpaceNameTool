//
//  NameSanitizerTests.swift
//  SpaceNameToolTests
//

import XCTest
@testable import SpaceNameToolCore

final class NameSanitizerTests: XCTestCase {
    func testStripsControlsAndTrims() {
        XCTAssertEqual(NameSanitizer.sanitize("  hi\nthere\u{0001}  "), "hithere")
    }

    func testEnforcesMaxLength() {
        let long = String(repeating: "a", count: 80)
        XCTAssertEqual(NameSanitizer.sanitize(long).count, NameSanitizer.maxLength)
    }
}
