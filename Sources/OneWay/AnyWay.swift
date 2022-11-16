import Foundation
import Combine

internal protocol AnyWay: AnyObject {
    associatedtype Action
    associatedtype State: Equatable

    var initialState: State { get }
    var currentState: State { get }
    var publisher: WayPublisher<State> { get }

    func reduce(state: inout State, action: Action) -> SideWay<Action, Never>
    func bind() -> SideWay<Action, Never>
    func send(_ action: Action)
    func reset()
}

