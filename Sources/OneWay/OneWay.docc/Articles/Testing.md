# Testing

Using OneWay for Unit Testing.

## Overview

**OneWay** provides the `expect` function to help you write concise and clear tests. This function works asynchronously, allowing you to verify whether the state updates as expected.

Before using the `expect` function, make sure to import the **OneWayTesting** module.

```swift
import OneWayTesting
```

When testing a reducer, you need to use `Store` instead of `ViewStore` for the `expect` function to be available.

```swift
let sut = Store(
    reducer: TestReducer(),
    state: TestReducer.State(count: 0)
)
await sut.send(.increment)
await sut.expect(\.count, 1)
```

The completion of `send`'s `await` literally means that `send` has finished. It does not mean that the state has fully changed. The state change always happpens asynchronously. Therefore, tests should be written using the `expect` function.

#### When using Testing

You can use the `expect` function to easily check the state value.

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2)
}
```

#### When using XCTest

The `expect` function is used in the same way within the `XCTest` environment.

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2)
}
```

## Specifying timeout if needed

Both functions include a `timeout` parameter, which specifies the maximum amount of time (in seconds) to wait for the state to finish processing before timing out. The default value is 2 seconds.

#### When using Testing

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2, timeout: 0.1)
}
```

#### When using XCTest

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2, timeout: 5)
}
```

## Diagnosing Issues

When a test fails, the output provides detailed information about the failure, making it easier to diagnose the issue. Below are example screenshots showing how a failure appears.

#### When using Testing

![failure with expect](expect-testing-failure.png)

#### When using XCTest

![failure with xctExpect](expect-xctest-failure.png)
