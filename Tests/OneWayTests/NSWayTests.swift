import XCTest
import Combine
import OneWay

final class NSWayTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func test_conformNSObjectProtocol() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))
        let anyWay: Any = way
        XCTAssertTrue(anyWay is NSObjectProtocol)
        XCTAssertNotNil(anyWay as? NSObject)
    }

    func test_initialState() {
        let way = TestNSWay(initialState: .init(number: 10, text: "Hello"))

        way.send(.increment)
        way.send(.saveText("World"))

        XCTAssertEqual(way.initialState.number, 10)
        XCTAssertEqual(way.initialState.text, "Hello")
    }

    func test_consumeSeveralActions() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))

        way.send(.increment)
        way.send(.increment)
        way.send(.decrement)
        way.send(.twice)
        way.send(.decrement)

        XCTAssertEqual(way.currentState.number, 2)
    }

    func test_bindGlobalSubjects() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))

        globalNumberSubject.send(10)
        XCTAssertEqual(way.currentState.number, 10)
        globalNumberSubject.send(20)
        XCTAssertEqual(way.currentState.number, 20)
        globalNumberSubject.send(30)
        XCTAssertEqual(way.currentState.number, 30)

        globalTextSubject.send("Hello")
        XCTAssertEqual(way.currentState.text, "Hello")
        globalTextSubject.send("World")
        XCTAssertEqual(way.currentState.text, "World")
    }

    func test_receiveWithRemovingDuplicates() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))
        var numberArray: [Int] = []

        way.publisher.number
            .sink { number in
                numberArray.append(number)
            }
            .store(in: &cancellables)

        way.send(.saveNumber(10))
        way.send(.saveNumber(10))
        way.send(.saveNumber(20))
        way.send(.saveNumber(20))
        way.send(.saveNumber(10))
        way.send(.saveNumber(30))
        way.send(.saveNumber(30))
        way.send(.saveNumber(30))

        XCTAssertEqual(numberArray, [0, 10, 20, 10, 30])
    }

    func test_receiveWithoutRemovingDuplicates() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))
        var numberArray: [Int] = []

        way.publisher.map(\.number)
            .sink { number in
                numberArray.append(number)
            }
            .store(in: &cancellables)

        way.send(.saveNumber(10))
        way.send(.saveNumber(10))
        way.send(.saveNumber(20))
        way.send(.saveNumber(20))
        way.send(.saveNumber(10))
        way.send(.saveNumber(30))
        way.send(.saveNumber(30))
        way.send(.saveNumber(30))

        XCTAssertEqual(numberArray, [0, 10, 10, 20, 20, 10, 30, 30, 30])
    }

    func test_lotsOfSynchronousActions() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))
        way.send(.incrementMany)
        XCTAssertEqual(way.currentState.number, 100_000)
    }

    func test_threadSafeSendingActions() {
        let queue = DispatchQueue(label: "OneWay.Actions.ConcurrentQueue", attributes: .concurrent)
        let group = DispatchGroup()
        let way = TestNSWay(
            initialState: .init(number: 0, text: ""),
            threadOption: .threadSafe
        )

        queue.async(group: group) {
            for _ in 1...10_000 {
                way.send(.increment)
            }
        }

        queue.async(group: group) {
            for _ in 1...10_000 {
                way.send(.increment)
            }
        }

        queue.async(group: group) {
            for _ in 1...10_000 {
                way.send(.increment)
            }
        }

        let expectation = expectation(description: "\(#function)")
        wait(seconds: 5, expectation: expectation, queue: queue)
        XCTAssertEqual(way.currentState.number, 30_000)
    }

    func test_asynchronousSideWaySuccessInMainThread() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))

        way.publisher.number
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
            }
            .store(in: &cancellables)

        way.send(.fetchDelayedNumber)
        XCTAssertEqual(way.currentState.number, 0)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.currentState.number, 10)
    }

    func test_asynchronousSideWayFailure() {
        let way = TestNSWay(initialState: .init(number: 0, text: ""))
        way.send(.fetchDelayedNumberWithError)
        XCTAssertEqual(way.currentState.number, 0)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.currentState.number, -1)
    }

}
