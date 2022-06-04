import Foundation

open class NSWay<Action, State>: NSObject, OneWay {

    private let wrappedValue: Way<Action, State>

    public var initialState: State { wrappedValue.initialState }

    public var currentState: State { wrappedValue.currentState }

    public var publisher: WayPublisher<State> { wrappedValue.publisher }

    public init(initialState: State, threadOption: ThreadOption = .current) {
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

    open func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
        return .none
    }

    open func bind() -> SideWay<Action, Never> {
        return .none
    }

    public func send(_ action: Action) {
        wrappedValue.send(action)
    }
}
