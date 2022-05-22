import XCTest
import OneWay
import Combine

final class OneWayTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    func test_consumeSevralActions() throws {
        let initialValue = TestWay.InitialValue(number: 0, text: "")
        let way = TestWay(initialValue: initialValue)

        way.send(.increment)
        way.send(.increment)
        way.send(.decrement)
        way.send(.twice)
        way.send(.decrement)

        XCTAssertEqual(way.currentState.number, 2)
    }

    func test_bindGlobalSubjects() throws {
        let initialValue = TestWay.InitialValue(number: 0, text: "InitialValue")
        let way = TestWay(initialValue: initialValue)

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

    func testLotsOfSynchronousActions() throws {
        final class TestWay: Way<TestWay.Action, TestWay.State> {
            enum Action {
                case increment
            }

            struct State: Hashable {
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

        let way = TestWay(initialState: TestWay.State(number: 0))
        way.send(.increment)
        XCTAssertEqual(way.currentState.number, 100_000)
    }

    func test_threadSafeSendingActions() throws {
        let expectation = expectation(description: "\(#function)")
        let queue = DispatchQueue(label: "OneWay.Actions.ConcurrentQueue", attributes: .concurrent)
        let group = DispatchGroup()
        let initialValue = TestWay.InitialValue(number: 0, text: "")
        let way = TestWay(initialValue: initialValue, threadOption: .threadSafe)

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
}

private let globalTextSubject = PassthroughSubject<String, Never>()
private let globalNumberSubject = PassthroughSubject<Int, Never>()

private final class TestWay: Way<TestWay.Action, TestWay.State> {

    struct InitialValue {
        let number: Int
        let text: String
    }

    enum Action {
        case increment
        case decrement
        case twice
        case saveText(String)
        case saveNumber(Int)
    }

    struct State: Hashable {
        var number: Int
        var text: String
    }

    init(initialValue: InitialValue, threadOption: ThreadOption = .current) {
        let initialState = State(
            number: initialValue.number,
            text: initialValue.text
        )
        super.init(initialState: initialState, threadOption: threadOption)
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
