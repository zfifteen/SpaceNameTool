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

    func testStripsDELAndC1() {
        XCTAssertEqual(NameSanitizer.sanitize("ok\u{007F}\u{0081}x"), "okx")
    }

    func testEmptyAfterStrip() {
        XCTAssertEqual(NameSanitizer.sanitize("\u{0001}\u{0002}"), "")
    }
}
