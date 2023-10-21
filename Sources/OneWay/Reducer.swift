//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// A protocol defining a reduce fuction to transition the current state to the next state and a
/// bind function for observing global states.
public protocol Reducer<Action, State>: Sendable {
    associatedtype Action: Sendable
    associatedtype State: Equatable

    func bind() -> AnyEffect<Action>
    func reduce(state: inout State, action: Action) -> AnyEffect<Action>
}

extension Reducer {
    public func bind() -> AnyEffect<Action> {
        // Default implementation
        return .none
    }
}
