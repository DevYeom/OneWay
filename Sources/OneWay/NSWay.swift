// The MIT License (MIT)
//
// Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).

import Foundation
import Combine

/// The ``NSWay`` is useful when NSObject must be inherited. Since ``Way`` is a class, multiple
/// inheritance is not possible. To solve this problem, it is made by wrapping the ``Way``.
open class NSWay<Action, State>: NSObject, AnyWay, ObservableObject where State: Equatable {

    /// The initial state.
    public var initialState: State { wrappedValue.initialState }

    /// The current state.
    public var state: State { wrappedValue.state }

    /// The current state.
    @available(*, deprecated, renamed: "state")
    public var currentState: State { state }

    /// A publisher that emits when the state changes.
    public var publisher: WayPublisher<State> { wrappedValue.publisher }

    /// A wrapped way that has an actual implementation.
    private let wrappedValue: Way<Action, State>
    private var stateCancellable: AnyCancellable?

    /// Initializes a way from an initial state, threadOption.
    ///
    /// - Parameters:
    ///   - initialState: The state to initialize a way.
    ///   - threadOption: The option to determine thread environment. Default value is `current`
    public init(
        initialState: State,
        threadOption: ThreadOption = .current
    ) {
        defer {
            applyStateSubscription()
        }

        self.wrappedValue = Way(initialState: initialState, threadOption: threadOption)
        super.init()
        self.wrappedValue.reduceHandler = { [weak self] state, action in
            guard let self = self else { return .none }
            return self.reduce(state: &state, action: action)
        }
        self.wrappedValue.bindHandler = { [weak self] in
            guard let self = self else { return .none }
            return self.bind()
        }
    }

    /// Evolves the current state of the way to the next state.
    ///
    /// - Parameters:
    ///   - state: The current state of the way.
    ///   - action: The action that causes the current state of the way to change.
    open func reduce(
        state: inout State,
        action: Action
    ) -> SideWay<Action, Never> {
        return .none
    }

    /// Binds the global states to causes the current state of the way to change.
    ///
    /// - Returns: A sideWay to deliver an action.
    open func bind() -> SideWay<Action, Never> {
        return .none
    }

    /// Sends an action to the way.
    ///
    /// - Parameters:
    ///   - action: An action to perform `reduce(state:action:)`
    public func send(
        _ action: Action
    ) {
        wrappedValue.send(action)
    }

    /// Reset some properties and subscriptions. This is useful when you need to call `bind()` again.
    public func reset() {
        wrappedValue.reset()
        applyStateSubscription()
    }

    private func applyStateSubscription() {
        stateCancellable?.cancel()
        stateCancellable = wrappedValue.objectWillChange
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.stateCancellable = nil
                },
                receiveValue: { [weak self] _ in
                    self?.objectWillChange.send()
                }
            )
    }

}
