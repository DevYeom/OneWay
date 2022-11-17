import XCTest
import Combine
import OneWay

final class SideWayTests: XCTestCase {

    private var number: Int?
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        number = nil
    }

    func test_concat() {
        var numbers: [Int] = []
        SideWay<Int, Never>.concat(
            .just(1)
            .delay(for: .milliseconds(20), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, []) })
            .eraseToSideWay(),
            .just(2)
            .delay(for: .milliseconds(10), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, [1]) })
            .eraseToSideWay(),
            .just(3)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, [1, 2]) })
            .eraseToSideWay()
        )
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 100, expectation: expectation)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    func test_merge() {
        var numbers: [Int] = []
        SideWay<Int, Never>.merge(
            .just(1)
            .delay(for: .milliseconds(20), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, [3, 2]) })
            .eraseToSideWay(),
            .just(2)
            .delay(for: .milliseconds(10), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, [3]) })
            .eraseToSideWay(),
            .just(3)
            .handleEvents(receiveOutput: { _ in XCTAssertEqual(numbers, []) })
            .eraseToSideWay()
        )
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 100, expectation: expectation)
        XCTAssertEqual(numbers, [3, 2, 1])
    }

#if canImport(_Concurrency)
    func test_asyncEmpty() {
        SideWay<Int, Never>.asyncEmpty { [weak self] in
            self?.number = await twelve()
        }
        .sink(receiveValue: { _ in XCTFail() })
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 10, expectation: expectation)
        XCTAssertEqual(number, 12)
    }

    func test_asyncNeverFailureWithReturnValue() {
        var result: Int?
        SideWay<Int, Never>.async {
            return await twelve()
        }
        .sink(receiveValue: { result = $0 })
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 10, expectation: expectation)
        XCTAssertEqual(result, 12)
    }

    func test_asyncFailureWithReturnValue() {
        var result: Int?
        SideWay<Int, Error>.async {
            return await twelve()
        }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { result = $0 }
        )
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 10, expectation: expectation)
        XCTAssertEqual(result, 12)
    }

    func test_asyncThrowsError() {
        var result: Error?
        SideWay<Int, Error>.async {
            return try await twelveWithError()
        }
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail()
                case let .failure(error):
                    result = error
                }
            },
            receiveValue: { _ in XCTFail() }
        )
        .store(in: &cancellables)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 10, expectation: expectation)
        XCTAssertNotNil(result)
    }
#endif
}

@Sendable
private func twelve() async -> Int {
    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
    return 12
}

@Sendable
private func twelveWithError() async throws -> Int {
    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
    throw SideWayError()
}

private struct SideWayError: Error {}
