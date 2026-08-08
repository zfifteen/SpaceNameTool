import XCTest
@testable import SpaceNameToolCore

final class DebouncedActionTests: XCTestCase {
    func testCoalescesRapidCalls() {
        let exp = expectation(description: "debounce")
        let queue = DispatchQueue(label: "test.debounce")
        let debounce = DebouncedAction(delay: 0.05, queue: queue)
        var count = 0
        for _ in 0..<5 {
            debounce.schedule { count += 1 }
        }
        queue.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(count, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
