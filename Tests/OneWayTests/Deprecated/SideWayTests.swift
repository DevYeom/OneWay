// The MIT License (MIT)
//
// Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).

import XCTest
import Combine
import CombineSchedulers
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
        let scheduler = DispatchQueue.test
        var numbers: [Int] = []

        SideWay<Int, Never>.concat(
            .just(1)
            .delay(for: 300, scheduler: scheduler)
            .eraseToSideWay(),
            .just(2)
            .delay(for: 200, scheduler: scheduler)
            .eraseToSideWay(),
            .just(3)
            .delay(for: 100, scheduler: scheduler)
            .eraseToSideWay()
        )
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertEqual(numbers, [])
        scheduler.advance(by: 300)
        XCTAssertEqual(numbers, [1])
        scheduler.advance(by: 200)
        XCTAssertEqual(numbers, [1, 2])
        scheduler.advance(by: 100)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    func test_merge() {
        let scheduler = DispatchQueue.test
        var numbers: [Int] = []

        SideWay<Int, Never>.merge(
            .just(1)
            .delay(for: 300, scheduler: scheduler)
            .eraseToSideWay(),
            .just(2)
            .delay(for: 200, scheduler: scheduler)
            .eraseToSideWay(),
            .just(3)
            .delay(for: 100, scheduler: scheduler)
            .eraseToSideWay()
        )
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertEqual(numbers, [])
        scheduler.advance(by: 100)
        XCTAssertEqual(numbers, [3])
        scheduler.advance(by: 100)
        XCTAssertEqual(numbers, [3, 2])
        scheduler.advance(by: 100)
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

    func test_catch() {
        var errorResult: Error?
        var numbers: [Int] = []

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catch { error in
            errorResult = error
            return -1
        }
        .sink(receiveValue: { numbers.append($0) })
        .store(in: &cancellables)

        XCTAssertNotNil(errorResult)
        XCTAssertEqual(numbers, [-1])
    }

    func test_catchToResult() {
        var errorResult: Error?

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToResult()
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

    func test_catchToResultWithTransform() {
        var errorResult: Error?
        var numbers: [Int] = []

        SideWay<Int, Error>.future { promise in
            promise(.failure(WayError()))
        }
        .catchToResult { result in
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
    func test_asyncNeverFailureWithReturnValue() {
        let expectation = expectation(description: "\(#function)")
        var result: Int?

        SideWay<Int, Never>.async {
            return await twelve()
        }
        .sink(
            receiveValue: {
                result = $0
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(result, 12)
    }

    func test_asyncFailureWithReturnValue() {
        let expectation = expectation(description: "\(#function)")
        var result: Int?

        SideWay<Int, Error>.async {
            return await twelve()
        }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: {
                result = $0
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(result, 12)
    }

    func test_asyncThrowsError() {
        let expectation = expectation(description: "\(#function)")
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
                    expectation.fulfill()
                }
            },
            receiveValue: { _ in XCTFail() }
        )
        .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)
        XCTAssertNotNil(result)
    }
#endif

}

#if canImport(_Concurrency)
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
#endif
