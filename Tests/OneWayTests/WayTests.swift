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

    func test_consumeSevralActions() {
        let way = TestWay(initialState: .init(number: 0, text: ""))

        way.send(.increment)
        way.send(.increment)
        way.send(.decrement)
        way.send(.twice)
        way.send(.decrement)

        XCTAssertEqual(way.currentState.number, 2)
    }

    func test_bindGlobalSubjects() {
        let way = TestWay(initialState: .init(number: 0, text: ""))

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

    func testLotsOfSynchronousActions() {
        final class TestWay: Way<TestWay.Action, TestWay.State> {
            enum Action {
                case increment
            }

            struct State: Equatable {
                var number: Int
            }

            override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
                switch action {
                case .increment:
                    state.number += 1
                    return state.number >= 100_000 ? .none : .just(.increment)
                }
            }
        }

        let way = TestWay(initialState: .init(number: 0))
        way.send(.increment)
        XCTAssertEqual(way.currentState.number, 100_000)
    }

    func test_threadSafeSendingActions() {
        let expectation = expectation(description: "\(#function)")
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

        wait(seconds: 1, expectation: expectation, queue: queue)
        XCTAssertEqual(way.currentState.number, 30_000)
    }

    func test_AsynchronousSideWaySuccessInMainThread() {
        final class TestWay: Way<TestWay.Action, TestWay.State> {
            enum Action {
                case saveNumber(Int)
                case fetchRemoteNumber
            }

            struct State: Equatable {
                var number: Int
            }

            override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
                switch action {
                case .saveNumber(let number):
                    state.number = number
                    return .none
                case .fetchRemoteNumber:
                    return SideWay<Int, Never>
                        .future { result in
                            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
                                result(.success(10))
                                result(.success(20))
                            }
                        }
                        .receive(on: DispatchQueue.main)
                        .map({ Action.saveNumber($0) })
                        .eraseToSideWay()
                }
            }
        }

        let expectation = expectation(description: "\(#function)")
        let way = TestWay(initialState: .init(number: 0))

        way.publisher.number
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
            }
            .store(in: &cancellables)

        way.send(.fetchRemoteNumber)
        XCTAssertEqual(way.currentState.number, 0)
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.currentState.number, 10)
    }

    func test_AsynchronousSideWayFailure() {
        final class TestWay: Way<TestWay.Action, TestWay.State> {
            struct Error: Swift.Error, Equatable {}

            enum Action {
                case saveNumber(Int)
                case fetchRemoteNumber
            }

            struct State: Equatable {
                var number: Int
            }

            override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
                switch action {
                case .saveNumber(let number):
                    state.number = number
                    return .none
                case .fetchRemoteNumber:
                    return SideWay<Int, Error>
                        .future { result in
                            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
                                result(.failure(Error()))
                            }
                        }
                        .eraseToSideWay({ Action.saveNumber($0) })
                        .catchToReturn(Action.saveNumber(-1))
                }
            }
        }

        let expectation = expectation(description: "\(#function)")
        let way = TestWay(initialState: .init(number: 0))

        way.send(.fetchRemoteNumber)
        XCTAssertEqual(way.currentState.number, 0)
        wait(milliseconds: 200, expectation: expectation)
        XCTAssertEqual(way.currentState.number, -1)
    }
}

private let globalTextSubject = PassthroughSubject<String, Never>()
private let globalNumberSubject = PassthroughSubject<Int, Never>()

private final class TestWay: Way<TestWay.Action, TestWay.State> {

    enum Action {
        case increment
        case decrement
        case twice
        case saveText(String)
        case saveNumber(Int)
    }

    struct State: Equatable {
        var number: Int
        var text: String
    }

    override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
        switch action {
        case .increment:
            state.number += 1
            return .none
        case .decrement:
            state.number -= 1
            return .none
        case .twice:
            return .concat(
                .just(.increment),
                .just(.increment)
            )
        case .saveText(let text):
            state.text = text
            return .none
        case .saveNumber(let number):
            state.number = number
            return .none
        }
    }

    override func bind() -> SideWay<Action, Never> {
        return .merge(
            globalTextSubject
                .map({ Action.saveText($0) })
                .eraseToSideWay(),
            globalNumberSubject
                .map({ Action.saveNumber($0) })
                .eraseToSideWay()
        )
    }
}
