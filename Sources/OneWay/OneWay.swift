import Foundation
import Combine

internal protocol OneWay: AnyObject {
    associatedtype Action

    associatedtype State

    /// The initial state.
    var initialState: State { get }

    /// The current state.
    var currentState: State { get }

    /// A publisher that emits when state changes.
    var publisher: WayPublisher<State> { get }

    func reduce(state: inout State, action: Action) -> SideWay<Action, Never>

    func bind() -> SideWay<Action, Never>

    func send(_ action: Action)
}

