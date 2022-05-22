import Foundation
import Combine

open class Way<Action, State> {

    public enum ThreadOption {
        case current
        case threadSafe
    }

    public let initialState: State
    public var currentState: State { stateSubject.value }
    public var publisher: WayPublisher<State> {
        WayPublisher(way: self)
    }

    internal var stateSubject: CurrentValueSubject<State, Never>

    private let threadOption: ThreadOption

    private var actionSubject: PassthroughSubject<Action, Never>!
    private let actionQueue: DispatchQueue!

    private var isSending: Bool = false
    private var bufferedActions: [Action] = []
    private var sideWayCancellables: [UUID: AnyCancellable] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var bindCancellable: AnyCancellable?

    public init(initialState: State, threadOption: ThreadOption = .current) {
        self.initialState = initialState
        self.threadOption = threadOption
        self.stateSubject = CurrentValueSubject(initialState)

        switch threadOption {
        case .current:
            actionSubject = nil
            actionQueue = nil
        case .threadSafe:
            actionSubject = PassthroughSubject()
            actionQueue = DispatchQueue(label: "OneWay.Actions.SerialQueue")
            actionSubject
                .receive(on: actionQueue)
                .sink(receiveValue: { [weak self] action in
                    self?.bufferedActions.append(action)
                })
                .store(in: &cancellables)
            actionSubject
                .debounce(for: .milliseconds(1), scheduler: actionQueue)
                .sink(receiveValue: { [weak self] _ in
                    self?.consume()
                })
                .store(in: &cancellables)
        }

        bindCancellable = bind()
            .sink(receiveCompletion: { [weak self] _ in
                self?.bindCancellable = nil
            }, receiveValue: { [weak self] action in
                self?.send(action)
            })
    }

    open func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
        return .none
    }

    open func bind() -> SideWay<Action, Never> {
        return .none
    }

    public func send(_ action: Action) {
        switch threadOption {
        case .current:
            bufferedActions.append(action)
            guard !isSending else { return }
            consume()
        case .threadSafe:
            assert(actionSubject != nil, "ActionSubject must be not nil")
            actionSubject.send(action)
        }
    }

    private func consume() {
        isSending = true
        var currentState = self.stateSubject.value
        defer {
            isSending = false
            self.stateSubject.value = currentState
        }

        while !bufferedActions.isEmpty {
            let action = bufferedActions.removeFirst()
            let sideWay = reduce(state: &currentState, action: action)

            var didComplete = false
            let uuid = UUID()
            let sideWayCancellable = sideWay
                .sink(
                    receiveCompletion: { [uuid, weak self] _ in
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

}

@dynamicMemberLookup
public struct WayPublisher<State>: Publisher {
    public typealias Output = State
    public typealias Failure = Never

    public let upstream: AnyPublisher<State, Never>
    public let way: Any

    internal init<Action>(way: Way<Action, State>) {
        self.way = way
        self.upstream = way.stateSubject.eraseToAnyPublisher()
    }

    private init<P>(upstream: P, way: Any)
    where P: Publisher, Failure == P.Failure, Output == P.Output {
        self.upstream = upstream.eraseToAnyPublisher()
        self.way = way
    }

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
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

    public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> WayPublisher<LocalState> where LocalState: Equatable {
        WayPublisher<LocalState>(upstream: upstream.map(keyPath).removeDuplicates(), way: way)
    }
}
