<img src="https://github.com/DevYeom/OneWay/blob/assets/oneway_logo.png" alt="oneway_logo"/>

<p align="center">
  <a href="https://github.com/DevYeom/OneWay/releases/latest">
    <img alt="release" src="https://img.shields.io/github/v/release/DevYeom/OneWay.svg">
  </a>
  <a href="https://github.com/DevYeom/OneWay/actions">
    <img alt="CI" src="https://github.com/DevYeom/OneWay/workflows/CI/badge.svg">
  </a>
  <a href="LICENSE">
    <img alt="license" src="https://img.shields.io/badge/license-MIT-indigo.svg">
  </a>
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/DevYeom/OneWay">
    <img alt="Swift" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDevYeom%2FOneWay%2Fbadge%3Ftype%3Dswift-versions">
  </a>
  <a href="https://swiftpackageindex.com/DevYeom/OneWay">
    <img alt="Platforms" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FDevYeom%2FOneWay%2Fbadge%3Ftype%3Dplatforms">
  </a>
</p>

**OneWay** is a simple, lightweight library for state management using a unidirectional data flow, fully compatiable with Swift 6 and built on [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/). Its structure makes it easier to maintain thread safety at all times.

It integrates effortlessly across platforms and frameworks, with zero third-party dependencies, allowing you to use it in its purest form. **OneWay** can be used anywhere, not just in the presentation layer, to simplify the complex business logic. If you're looking to implement unidirectional logic, **OneWay** is a straightforward and practical solution.

- [Data Flow](#data-flow)
- [Usage](#usage)
- [Documentation](#documentation)
- [Examples](#examples)
- [Requirements](#requirements)
- [Installation](#installation)
- [References](#references)

## Data Flow

When using the `Store`, the data flow is as follows.

<img src="https://github.com/DevYeom/OneWay/blob/assets/flow_description_v2_1.png" alt="flow_description_1"/>

When working on UI, it is better to use `ViewStore` to ensure main thread operation.

<img src="https://github.com/DevYeom/OneWay/blob/assets/flow_description_v2_2.png" alt="flow_description_1"/>

## Usage

### Implementing a Reducer

After adopting the `Reducer` protocol, define the `Action` and `State`, and then implement the logic for each `Action` within the `reduce(state:action:)` function.

```swift
struct CountingReducer: Reducer {
    enum Action: Sendable {
        case increment
        case decrement
        case twice
        case setIsLoading(Bool)
    }

    struct State: Sendable, Equatable {
        var number: Int
        var isLoading: Bool
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.number += 1
            return .none
        case .decrement:
            state.number -= 1
            return .none
        case .twice:
            return .concat(
                .just(.setIsLoading(true)),
                .merge(
                    .just(.increment),
                    .just(.increment)
                ),
                .just(.setIsLoading(false))
            )
        case .setIsLoading(let isLoading):
            state.isLoading = isLoading
            return .none
        }
    }
}
```

### Sending Actions

Sending an action to a **Store** causes changes in the `state` via `Reducer`.

```swift
let store = Store(
    reducer: CountingReducer(),
    state: CountingReducer.State(number: 0)
)

await store.send(.increment)
await store.send(.decrement)
await store.send(.twice)

print(await store.state.number) // 2
```

The usage is the same for `ViewStore`. However, when working within `MainActor`, such as in `UIViewController` or `View`'s body, `await` can be omitted.

```swift
let store = ViewStore(
    reducer: CountingReducer(),
    state: CountingReducer.State(number: 0)
)

store.send(.increment)
store.send(.decrement)
store.send(.twice)

print(store.state.number) // 2
```

### Observing States

When the state changes, you can receive a new state. It guarantees that the same state does not come down consecutively.

```swift
struct State: Sendable, Equatable {
    var number: Int
}

// number <- 10, 10, 20 ,20

for await state in store.states {
    print(state.number)
}
// Prints "10", "20"
```

Of course, you can observe specific properties only.

```swift
// number <- 10, 10, 20 ,20

for await number in store.states.number {
    print(number)
}
// Prints "10", "20"
```

If you want to continue receiving the value even when the same value is assigned to the `State`, you can use `@Triggered`. For explanations of other useful property wrappers(e.g. [@CopyOnWrite](https://swiftpackageindex.com/devyeom/oneway/main/documentation/oneway/copyonwrite), [@Ignored](https://swiftpackageindex.com/devyeom/oneway/main/documentation/oneway/ignored)), refer to [here](https://swiftpackageindex.com/devyeom/oneway/main/documentation/oneway/triggered).

```swift
struct State: Sendable, Equatable {
    @Triggered var number: Int
}

// number <- 10, 10, 20 ,20

for await state in store.states {
    print(state.number)
}
// Prints "10", "10", "20", "20"
```

When there are multiple properties of the state, it is possible for the state to change due to other properties that are not subscribed to. In such cases, if you are using [AsyncAlgorithms](https://github.com/apple/swift-async-algorithms), you can remove duplicates as follows.

```swift
struct State: Sendable, Equatable {
    var number: Int
    var text: String
}

// number <- 10
// text <- "a", "b", "c"

for await number in store.states.number {
    print(number)
}
// Prints "10", "10", "10"

for await number in store.states.number.removeDuplicates() {
    print(number)
}
// Prints "10"
```

### Cancelling Effects

You can make an effect capable of being canceled by using `cancellable()`. And you can use `cancel()` to cancel a cancellable effect.

```swift
func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
    switch action {
// ...
    case .request:
        return .single {
            let result = await api.result()
            return Action.response(result)
        }
        .cancellable("requestID")

    case .cancel:
        return .cancel("requestID")
// ...
    }
}
```

You can assign anything that conforms [Hashable](https://developer.apple.com/documentation/swift/hashable) as an identifier for the effect, not just a string.

```swift
enum EffectID {
    case request
}

func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
    switch action {
// ...
    case .request:
        return .single {
            let result = await api.result()
            return Action.response(result)
        }
        .cancellable(EffectID.request)

    case .cancel:
        return .cancel(EffectID.request)
// ...
    }
}
```

### Various Effects

**OneWay** supports various effects such as `just`, `concat`, `merge`, `single`, `sequence`, and more. For more details, please refer to the [documentation](https://swiftpackageindex.com/devyeom/oneway/main/documentation/oneway/effects).

### External States

You can easily receive to external states by implementing `bind()`. If there are changes in publishers or streams that necessitate rebinding, you can call `reset()` of `Store`.

```swift
let textPublisher = PassthroughSubject<String, Never>()
let numberPublisher = PassthroughSubject<Int, Never>()

struct CountingReducer: Reducer {
// ...
    func bind() -> AnyEffect<Action> {
        return .merge(
            .sequence { send in
                for await text in textPublisher.values {
                    send(Action.response(text))
                }
            },
            .sequence { send in
                for await number in numberPublisher.values {
                    send(Action.response(String(number)))
                }
            }
        )
    }
// ...
}
```

## Documentation

To learn how to use **OneWay** in more detail, go through the [documentation](https://swiftpackageindex.com/DevYeom/OneWay/main/documentation/OneWay).

## Examples

- [OneWayExample](https://github.com/DevYeom/OneWayExample)
  - [UIKit](https://github.com/DevYeom/OneWayExample/tree/main/CounterUIKit/Counter)
  - [SwiftUI](https://github.com/DevYeom/OneWayExample/tree/main/CounterSwiftUI/Counter)

## Requirements

| OneWay | Swift | Xcode | Platforms                                                   |
|--------|-------|-------|-------------------------------------------------------------|
| 2.0    | 5.9   | 15.0  | iOS 13.0, macOS 10.15, tvOS 13.0, visionOS 1.0, watchOS 6.0 |
| 1.0    | 5.5   | 13.0  | iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0               |

## Installation

**OneWay** is only supported by Swift Package Manager.

To integrate **OneWay** into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/DevYeom/OneWay", from: "2.0.0"),
]
```

## References

These are the references that have provided much inspiration.

- [Flux](https://github.com/facebook/flux)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [awesome-state](https://github.com/tnfe/awesome-state)

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
