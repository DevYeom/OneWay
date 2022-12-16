import Foundation
import Combine

/// The ``Way`` represents the path through which data passes. It is the object that can not only be
/// used in the presentation layer, but can also be used to simplify complex business logic. The
/// basic concept is to think of each way separately.
open class Way<Action, State>: AnyWay, ObservableObject where State: Equatable {

    /// The initial state.
    public let initialState: State

    /// The current state.
    public var currentState: State { stateSubject.value }

    /// A publisher that emits when the state changes.
    public var publisher: WayPublisher<State> {
        WayPublisher(way: self)
    }

    internal var stateSubject: CurrentValueSubject<State, Never>
    internal var reduceHandler: ((inout State, Action) -> SideWay<Action, Never>)?
    internal var bindHandler: (() -> SideWay<Action, Never>)? {
        didSet {
            applyBindSubscription()
        }
    }

    /// Use only when thread-safe mode.
    private let wayQueue: DispatchQueue!

    private let threadOption: ThreadOption
    private var isConsuming: Bool = false
    private var actionQueue: [Action] = []
    private var sideWayCancellables: [UUID: AnyCancellable] = [:]
    private var stateCancellable: AnyCancellable?
    private var bindCancellable: AnyCancellable?

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
            applyBindSubscription()
        }

        self.initialState = initialState
        self.threadOption = threadOption
        self.stateSubject = CurrentValueSubject(initialState)

        switch threadOption {
        case .current:
            wayQueue = nil
        case .threadSafe:
            wayQueue = DispatchQueue(label: "OneWay.Actions.SerialQueue")
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
        return reduceHandler?(&state, action) ?? .none
    }

    /// Binds the global states to causes the current state of the way to change.
    ///
    /// - Returns: A sideWay to deliver an action.
    open func bind() -> SideWay<Action, Never> {
        return bindHandler?() ?? .none
    }

    /// Sends an action to the way.
    ///
    /// - Parameters:
    ///   - action: An action to perform `reduce(state:action:)`
    final public func send(
        _ action: Action
    ) {
        switch threadOption {
        case .current:
            consume(action)
        case .threadSafe:
            wayQueue.async { [weak self, action] in
                self?.consume(action)
            }
        }
    }

    /// Reset some properties and subscriptions. This is useful when you need to call `bind()` again.
    final public func reset() {
        actionQueue.removeAll()
        sideWayCancellables.removeAll()
        isConsuming = false
        applyStateSubscription()
        applyBindSubscription()
    }

    private func consume(
        _ action: Action
    ) {
        actionQueue.append(action)
        guard !isConsuming else { return }

        isConsuming = true
        var currentState = stateSubject.value
        defer {
            isConsuming = false
            stateSubject.value = currentState
        }

        while !actionQueue.isEmpty {
            let action = actionQueue.removeFirst()
            let sideWay = reduce(state: &currentState, action: action)

            var didComplete = false
            let uuid = UUID()
            let sideWayCancellable = sideWay
                .sink(
                    receiveCompletion: { [weak self, uuid] _ in
                        didComplete = true
                        self?.sideWayCancellables[uuid] = nil
                    },
                    receiveValue: { [weak self] sideWayAction in
                        self?.send(sideWayAction)
                    }
                )

            if !didComplete {
                sideWayCancellables[uuid] = sideWayCancellable
            }
        }
    }

    private func applyStateSubscription() {
        stateCancellable?.cancel()
        stateCancellable = stateSubject
            .removeDuplicates()
            .sink(receiveCompletion: { [weak self] _ in
                self?.stateCancellable = nil
            }, receiveValue: { [weak self] _ in
                self?.objectWillChange.send()
            })
    }

    private func applyBindSubscription() {
        bindCancellable?.cancel()
        bindCancellable = bind()
            .sink(receiveCompletion: { [weak self] _ in
                self?.bindCancellable = nil
            }, receiveValue: { [weak self] action in
                self?.send(action)
            })
    }

}

/// A publisher of a ``Way``'s state.
///
/// This pulisher supports dynamic member lookup so that you can pluck out a specific field in the
/// state.
@dynamicMemberLookup
public struct WayPublisher<State>: Publisher {

    public typealias Output = State
    public typealias Failure = Never

    private let upstream: AnyPublisher<State, Never>
    private let way: Any

    internal init<Action>(
        way: Way<Action, State>
    ) {
        self.way = way
        self.upstream = way.stateSubject.eraseToAnyPublisher()
    }

    private init<P>(
        upstream: P,
        way: Any
    ) where P: Publisher, Failure == P.Failure, Output == P.Output {
        self.upstream = upstream.eraseToAnyPublisher()
        self.way = way
    }

    public func receive<S>(
        subscriber: S
    ) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.upstream.subscribe(
            AnySubscriber(
                receiveSubscription: subscriber.receive(subscription:),
                receiveValue: subscriber.receive(_:),
                receiveCompletion: { [way = self.way] in
                    subscriber.receive(completion: $0)
                    _ = way
                }
            )
        )
    }

    public subscript<LocalState>(
        dynamicMember keyPath: KeyPath<State, LocalState>
    ) -> WayPublisher<LocalState> where LocalState: Equatable {
        WayPublisher<LocalState>(upstream: upstream.map(keyPath).removeDuplicates(), way: way)
    }

}
