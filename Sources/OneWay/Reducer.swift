//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A protocol defining a reduce fuction to transition the current state to the next state and a
/// bind function for observing global states.
public protocol Reducer<Action, State> {
    associatedtype Action
    associatedtype State: Equatable

    func bind() -> AnyEffect<Action>
    func reduce(state: inout State, action: Action) -> AnyEffect<Action>
}

extension Reducer where Action: Sendable {
    public func bind() -> AnyEffect<Action> {
        // Default implementation
        return .none
    }
}
