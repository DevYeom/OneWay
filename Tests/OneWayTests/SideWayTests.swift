import XCTest
import Combine
import OneWay

final class SideWayTests: XCTestCase {

    private var number: Int?
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        number = nil
    }

    func test_just() {
        var numbers: [Int] = []

        SideWay<Int, Never>.just(10)
            .sink(receiveValue: { numbers.append($0) })
            .store(in: &cancellables)

        XCTAssertEqual(numbers, [10])
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

    func test_future() {
        var numbers: [Int] = []

        SideWay<Int, Never>.future { promise in
            promise(.success(10))
            promise(.success(20))
            promise(.success(30))
        }
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertEqual(numbers, [10])
    }

    func test_futureWithFail() {
        var result: Error?

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail()
                case .failure(let error):
                    result = error
                }
            },
            receiveValue: { _ in XCTFail() }
        )
        .store(in: &cancellables)

        XCTAssertNotNil(result)
    }

    func test_catchToSideWay() {
        var errorResult: Error?

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToSideWay()
        .sink(
            receiveValue: { result in
                switch result {
                case .success:
                    XCTFail()
                case .failure(let error):
                    errorResult = error
                }
            }
        )
        .store(in: &cancellables)

        XCTAssertNotNil(errorResult)
    }

    func test_catchToSideWayWithTransform() {
        var errorResult: Error?
        var numbers: [Int] = []

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToSideWay { result in
            switch result {
            case .success:
                return 10
            case .failure(let error):
                errorResult = error
                return -1
            }
        }
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertNotNil(errorResult)
        XCTAssertEqual(numbers, [-1])
    }

    func test_catchToNever() {
        var isFinished: Bool = false

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToNever()
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    isFinished = true
                case .failure:
                    XCTFail()
                }
            },
            receiveValue: { _ in XCTFail() }
        )
        .store(in: &cancellables)

        XCTAssertEqual(isFinished, true)
    }

    func test_catchToReturn() {
        var numbers: [Int] = []

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToReturn(-1)
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertEqual(numbers, [-1])
    }

    func test_emptyWithSuccess() {
        var isFinished: Bool = false

        SideWay<Int, Error>.future { promise in
            promise(.success(10))
        }
        .empty(
            outputType: Void.self,
            failureType: Never.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    isFinished = true
                case .failure:
                    XCTFail()
                }
            },
            receiveValue: {
                XCTFail()
            }
        )
        .store(in: &cancellables)

        XCTAssertEqual(isFinished, true)
    }

    func test_emptyWithFailure() {
        var isFinished: Bool = false

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .empty(
            outputType: Void.self,
            failureType: Never.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    isFinished = true
                case .failure:
                    XCTFail()
                }
            },
            receiveValue: {
                XCTFail()
            }
        )
        .store(in: &cancellables)

        XCTAssertTrue(isFinished)
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
    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC) // 1ms
    return 12
}

@Sendable
private func twelveWithError() async throws -> Int {
    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC) // 1ms
    throw WayError()
}
