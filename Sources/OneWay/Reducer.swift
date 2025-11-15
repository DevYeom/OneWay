//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A protocol that defines a reduce function to transition the current state to the next state and
/// a bind function for observing global states.
public protocol Reducer<Action, State>: Sendable {
    associatedtype Action
    associatedtype State: Equatable

    /// A function that observes and responds to external changes.
    ///
    /// You can use this function to subscribe to notifications or other data sources that are not
    /// directly tied to the view.
    ///
    /// - Returns: An effect that should be executed in response to the observed changes.
    func bind() -> AnyEffect<Action>

    /// A function that transitions the current state to the next state in response to an action.
    ///
    /// - Parameters:
    ///   - state: The current state of the feature.
    ///   - action: An action that has been sent.
    /// - Returns: An effect that can be executed by the `Store`.
    func reduce(state: inout State, action: Action) -> AnyEffect<Action>
}

extension Reducer where Action: Sendable {
    public func bind() -> AnyEffect<Action> {
        .none
    }
}
