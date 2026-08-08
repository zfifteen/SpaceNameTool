//
//  SpaceNameToolTests.swift
//  SpaceNameToolTests
//
//  Package smoke test.
//

import XCTest
@testable import SpaceNameToolCore

final class SpaceNameToolTests: XCTestCase {
    func testCoreModuleLinks() {
        XCTAssertEqual(NameSanitizer.maxLength, 50)
    }
}
