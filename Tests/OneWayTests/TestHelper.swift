import Foundation
import Combine
import XCTest

extension XCTestCase {
    func wait(
        seconds: Int,
        expectation: XCTestExpectation,
        queue: DispatchQueue = .main
    ) {
        wait(
            milliseconds: seconds * 1000,
            expectation: expectation,
            queue: queue
        )
    }

    func wait(
        seconds: Int,
        expectations: [XCTestExpectation],
        queue: DispatchQueue = .main
    ) {
        wait(
            milliseconds: seconds * 1000,
            expectations: expectations,
            queue: queue
        )
    }

    func wait(
        milliseconds: Int,
        expectation: XCTestExpectation,
        queue: DispatchQueue = .main
    ) {
        queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds),
            execute: { expectation.fulfill() }
        )
        wait(
            for: [expectation],
            timeout: 10
        )
    }

    func wait(
        milliseconds: Int,
        expectations: [XCTestExpectation],
        queue: DispatchQueue = .main
    ) {
        queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds),
            execute: { expectations.forEach { $0.fulfill() } }
        )
        wait(
            for: expectations,
            timeout: 10
        )
    }
}
