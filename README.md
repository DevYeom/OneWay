# OneWay

<p align="left">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.5-orange.svg">
  <a href="https://github.com/DevYeom/OneWay/releases/latest">
    <img alt="release" src="https://img.shields.io/github/v/release/DevYeom/OneWay.svg">
  </a>
  <a href="https://github.com/DevYeom/OneWay/actions" target="_blank">
    <img alt="CI" src="https://github.com/DevYeom/OneWay/workflows/CI/badge.svg">
  </a>
  <a href="LICENSE">
    <img alt="license" src="https://img.shields.io/badge/license-MIT-lightgray.svg">
  </a>
</p>

> 🚧 OneWay is still experimental. As such, expect things to break and change in the coming months.

**OneWay** is a super simple library for state management with unidirectional data flow. The original inspiration came from [Flux](https://github.com/facebook/flux), [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), [ReactorKit](https://github.com/ReactorKit/ReactorKit) and many state management [libraries](https://github.com/tnfe/awesome-state). There are no dependencies on third parties, so you can use **OneWay** purely. It can not only be used in the presentation layer (e.g. with View or ViewController), but can also be used to simplify complex business logic (e.g. while the app launches). The basic concept is to think of each way separately.

## Data Flow

<img src="https://github.com/DevYeom/OneWay/blob/assets/flow_description.png" alt="flow_description"/>

## Usage

### Implementing a Way

It is easy to think of a `Way` as a path through which data passes. You can inherit a `Way` and should implement as below. It is also freely customizable and encapsulatable, since `Way` is a class.

```swift
final class CounterWay: Way<CounterWay.Action, CounterWay.State> {

    enum Action {
        case increment
        case decrement
        case twice
    }

    struct State: Equatable {
        var number: Int
    }

    override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
        switch action {
        case .increment:
            state.number += 1
            return .none
        case .decrement:
            state.number -= 1
            return .none
        case .twice:
            return .concat(
                .just(.increment),
                .just(.increment)
            )
        }
    }
}
```

### Sending Actions

Sending an action to a `Way` causes changes in the `state` via `reduce()`.

```swift
let way = CounterWay(initialState: .init(number: 0))

way.send(.increment)
way.send(.decrement)
way.send(.twice)

print(way.currentState.number) // 2
```

### Subscribing a Way

When a value changes, it can receive a new value. It guarantees that the same value does not come down consecutively. In general, you don't need to add `removeDuplicates()`. But if you want to receive all values when the way's state changes, use `map` operator to way's publisher.

```swift
// number <- 10, 10, 20 ,20

way.publisher.number
    .sink { number in
        print(number) // 10, 20
    }
    .store(in: &cancellables)

way.publisher.map(\.number)
    .sink { number in
        print(number) // 10, 10, 20, 20
    }
    .store(in: &cancellables)
}
```

### Global States

You can easily subscribe to global states by overriding `bind()`.

```swift
let globalTextSubject = PassthroughSubject<String, Never>()
let globalNumberSubject = PassthroughSubject<Int, Never>()

final class CustomWay: Way<CustomWay.Action, CustomWay.State> {
// ...
    override func bind() -> SideWay<Action, Never> {
        return .merge(
            globalTextSubject
                .map({ Action.saveText($0) })
                .eraseToSideWay(),
            globalNumberSubject
                .map({ Action.saveNumber($0) })
                .eraseToSideWay()
        )
    }
// ...
}
```

### Supporting NSObject

**Way** is a class, not a protocol. Therefore, multiple inheritance is not possible. There are often situations where you have to inherit NSObject. NSWay was added for this occasion. In this case, inherit and implement NSWay, and in other cases, inherit Way.

```swift
final class TestWay: NSWay<TestWay.Action, TestWay.State> {
    // ...
}
```

### Thread Safe or Not

`Way` has a `ThreadOption` to consider the multithreaded environment. This option can be passed as an argument to the initializer. Once set, it cannot be changed. In a general environment, it is better to use the default option(`current`) for better performance. But, if it is initialized with the `current` option, all interactions (i.e. sending actions) with an instance of Way must be done on the same thread.

```swift
let way = TestWay(initialState: initialState, threadOption: .current)
let threadSafeWay = TestWay(initialState: initialState, threadOption: .threadSafe)
```

## Requirements

|       |Minimum Version|
|------:|--------------:|
|Swift  |5.5            |
|Xcode  |13.0           |
|iOS    |13.0           |
|macOS  |10.15          |

## Installation

**OneWay** is only supported by Swift Package Manager.

To integrate **OneWay** into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/DevYeom/OneWay", from: "0.1.0"),
]
```

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
