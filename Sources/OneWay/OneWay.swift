import Foundation
import Combine

internal protocol OneWay: AnyObject {
    associatedtype Action

    associatedtype State

    var initialState: State { get }

    var currentState: State { get }

    var publisher: WayPublisher<State> { get }

    func reduce(state: inout State, action: Action) -> SideWay<Action, Never>

    func bind() -> SideWay<Action, Never>

    func send(_ action: Action)
}

