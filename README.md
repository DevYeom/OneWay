<img src="https://github.com/DevYeom/OneWay/blob/assets/oneway_logo.png" alt="oneway_logo"/>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.5-orange.svg">
  <a href="https://github.com/DevYeom/OneWay/releases/latest">
    <img alt="release" src="https://img.shields.io/github/v/release/DevYeom/OneWay.svg">
  </a>
  <a href="https://github.com/DevYeom/OneWay">
    <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgray.svg">
  </a>
  <a href="https://github.com/DevYeom/OneWay/actions">
    <img alt="CI" src="https://github.com/DevYeom/OneWay/workflows/CI/badge.svg">
  </a>
  <a href="LICENSE">
    <img alt="license" src="https://img.shields.io/badge/license-MIT-indigo.svg">
  </a>
</p>

**OneWay** is a simple and lightweight library for state management with unidirectional data flow. It is fully supported for using anywhere that uses Swift. You can use it on any platform and with any framework. There are no dependencies on third parties, so you can use **OneWay** purely. It can not only be used in the presentation layer, but can also be used to simplify complex business logic. It will be useful whenever you want to design logic in unidirection.

- [Data Flow](#data-flow)
- [Usage](#usage)
- [Documentation](#documentation)
- [Benchmark](#benchmark)
- [Examples](#examples)
- [Requirements](#requirements)
- [Installation](#installation)
- [References](#references)

## Data Flow

<img src="https://github.com/DevYeom/OneWay/blob/assets/flow_description.png" alt="flow_description"/>

## Usage

### Implementing a Way

It is easy to think of a **Way** as a path through which data passes. You can inherit a **Way** and should implement as below. It is also freely customizable and encapsulatable, since **Way** is a class.

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

Sending an action to a **Way** causes changes in the `state` via `reduce()`.

```swift
let way = CounterWay(initialState: .init(number: 0))

way.send(.increment)
way.send(.decrement)
way.send(.twice)

print(way.state.number) // 2
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

final class CounterWay: Way<CounterWay.Action, CounterWay.State> {
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

### Catching Errors

There are several functions that handle errors. It is a little easier to understand if you refer to [unit tests](https://github.com/DevYeom/OneWay/blob/main/Tests/OneWayTests/SideWayTests.swift#L116-L213).

```swift
override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
    switch action {
    // ...
    case .fetchDataWithError:
        return fetchData()
            .map({ Action.dataDidLoad($0) })
            .catch({ Action.handleError($0) })
            .eraseToSideWay()
    case .fetchDataWithJustReturn:
        return fetchData()
            .map({ Action.dataDidLoad($0) })
            .catchToReturn(Action.failToLoad)
            .eraseToSideWay()
    case .fetchDataWithIgnoringErrors:
        return fetchData()
            .map({ Action.dataDidLoad($0) })
            .catchToNever()
            .eraseToSideWay()
    // ...
    }
}
```

### Swift Concurrency

`async/await` can also be used with **Way**.

```swift
final class CounterWay: Way<CounterWay.Action, CounterWay.State> {

    enum Action {
        case fetchNumber
        case setNumber(Int)
    }

    struct State: Equatable {
        var number: Int
    }

    override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
        switch action {
        case .fetchNumber:
            return .async {
                let number = await fetchNumber()
                return Action.setNumber(number)
            }
        case .setNumber(let number):
            state.number = number
            return .none
        }
    }

}
```

### Supporting NSObject

**Way** is a class, not a protocol. Therefore, multiple inheritance is not possible. There are often situations where you have to inherit NSObject. **NSWay** was added for this occasion. In this case, inherit and implement **NSWay**, and in other cases, inherit **Way**.

```swift
final class CounterWay: NSWay<CounterWay.Action, CounterWay.State> {
    // ...
}
```

### Thread Safe or Not

**Way** has a `ThreadOption` to consider the multithreaded environment. This option can be passed as an argument to the initializer. Once set, it cannot be changed. In a general environment, it is better to use the default option(`current`) for better performance. But, if it is initialized with the `current` option, all interactions (i.e. sending actions) with an instance of **Way** must be done on the same thread.

```swift
let way = CounterWay(initialState: initialState, threadOption: .current)
let threadSafeWay = CounterWay(initialState: initialState, threadOption: .threadSafe)
```

## Documentation

Learn how to use OneWay by going through the [documentation](https://devyeom-docs.github.io/oneway/documentation/oneway) created using DocC.

## Benchmark

Compared to other libraries, **OneWay** shows very good performance.

For more details, 👉 [OneWayBenchmark](https://github.com/DevYeom/OneWayBenchmark)

> Lower is better

<img src="https://github.com/DevYeom/OneWayBenchmark/blob/main/Resources/benchmark_220622_1.png" alt="Benchmark1"/>

<img src="https://github.com/DevYeom/OneWayBenchmark/blob/main/Resources/benchmark_220622_2.png" alt="Benchmark2"/>

## Examples

- [OneWayExample](https://github.com/DevYeom/OneWayExample)
  - [UIKit](https://github.com/DevYeom/OneWayExample/tree/main/CounterUIKit/Counter)
  - [SwiftUI](https://github.com/DevYeom/OneWayExample/tree/main/CounterSwiftUI/Counter)

## Requirements

|        |Minimum Version|
|-------:|--------------:|
|Swift   |5.5            |
|Xcode   |13.0           |
|iOS     |13.0           |
|macOS   |10.15          |
|tvOS    |13.0           |
|watchOS |6.0            |

## Installation

**OneWay** is only supported by Swift Package Manager.

To integrate **OneWay** into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/DevYeom/OneWay", from: "1.0.0"),
]
```

## Next Step

- [ ] Testing queue for asynchronous test case.
- [ ] Debugging tool that can log all actions and states.

## References

These are the references that inspired OneWay a lot.

- [Flux](https://github.com/facebook/flux)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [awesome-state](https://github.com/tnfe/awesome-state)

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
