import XCTest
import Combine
import OneWay

final class WayTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func test_initialState() {
        let way = TestWay(initialState: .init(number: 10, text: "Hello"))

        way.send(.increment)
        way.send(.saveText("World"))

        XCTAssertEqual(way.initialState.number, 10)
        XCTAssertEqual(way.initialState.text, "Hello")
    }

    func test_consumeSeveralActions() {
        let way = TestWay(initialState: .init(number: 0, text: ""))

        way.send(.increment)
        way.send(.increment)
        way.send(.decrement)
        way.send(.twice)
        way.send(.decrement)

        XCTAssertEqual(way.state.number, 2)
    }

    func test_bindGlobalSubjects() {
        let way = TestWay(initialState: .init(number: 0, text: ""))

        globalNumberSubject.send(10)
        XCTAssertEqual(way.state.number, 10)
        globalNumberSubject.send(20)
        XCTAssertEqual(way.state.number, 20)
        globalNumberSubject.send(30)
        XCTAssertEqual(way.state.number, 30)

        globalTextSubject.send("Hello")
        XCTAssertEqual(way.state.text, "Hello")
        globalTextSubject.send("World")
        XCTAssertEqual(way.state.text, "World")
    }

    func test_receiveWithRemovingDuplicates() {
        let way = TestWay(initialState: .init(number: 0, text: ""))
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
        let way = TestWay(initialState: .init(number: 0, text: ""))
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
        let way = TestWay(initialState: .init(number: 0, text: ""))
        way.send(.incrementMany)
        XCTAssertEqual(way.state.number, 100_000)
    }

    func test_threadSafeSendingActions() {
        let queue = DispatchQueue(label: "OneWay.Actions.ConcurrentQueue", attributes: .concurrent)
        let group = DispatchGroup()
        let way = TestWay(
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
        XCTAssertEqual(way.state.number, 30_000)
    }

    func test_asynchronousSideWaySuccessInMainThread() {
        let way = TestWay(initialState: .init(number: 0, text: ""))

        way.publisher.number
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
            }
            .store(in: &cancellables)

        way.send(.fetchDelayedNumber)
        XCTAssertEqual(way.state.number, 0)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.state.number, 10)
    }

    func test_asynchronousSideWayFailure() {
        let way = TestWay(initialState: .init(number: 0, text: ""))
        way.send(.fetchDelayedNumberWithError)
        XCTAssertEqual(way.state.number, 0)

        let expectation = expectation(description: "\(#function)")
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.state.number, -1)
    }

}
