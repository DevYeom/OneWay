import Foundation
import Combine
import OneWay

final class TestNSWay: NSWay<TestNSWay.Action, TestNSWay.State> {

    enum Action {
        case increment
        case incrementMany
        case decrement
        case twice
        case saveText(String)
        case saveNumber(Int)
        case fetchDelayedNumber
        case fetchDelayedNumberWithError
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
        case .incrementMany:
            state.number += 1
            return state.number >= 100_000 ? .none : .just(.incrementMany)
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
        case .fetchDelayedNumber:
            return SideWay<Int, Never>
                .future { result in
                    DispatchQueue.global().asyncAfter(
                        deadline: .now() + .milliseconds(100),
                        execute: {
                            result(.success(10))
                            result(.success(20))
                        }
                    )
                }
                .receive(on: DispatchQueue.main)
                .map({ Action.saveNumber($0) })
                .eraseToSideWay()
        case .fetchDelayedNumberWithError:
            return SideWay<Int, Error>
                .future { result in
                    DispatchQueue.global().asyncAfter(
                        deadline: .now() + .milliseconds(100),
                        execute: {
                            result(.failure(WayError()))
                        }
                    )
                }
                .map({ Action.saveNumber($0) })
                .catchToReturn(Action.saveNumber(-1))
                .eraseToSideWay()
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
