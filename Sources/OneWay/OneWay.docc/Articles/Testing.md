# Testing

Using **OneWay** for unit testing.

## Overview

**OneWay** provides an `expect` function to help you write concise and clear tests. This function works asynchronously, allowing you to verify that the state updates as expected.

Before using the `expect` function, be sure to import the **OneWayTesting** module.

```swift
import OneWayTesting
```

When testing a reducer, you should use a `Store` instead of a `ViewStore` to have access to the `expect` function.

```swift
let sut = Store(
    reducer: TestReducer(),
    state: TestReducer.State(count: 0)
)
await sut.send(.increment)
await sut.expect(\.count, 1)
```

The completion of `await` on `send` only indicates that the action has been sent, not that the state has been fully updated. State changes always occur asynchronously. Therefore, tests should be written using the `expect` function to ensure that you are asserting against the final state.

### When using Testing

You can use the `expect` function to easily check the state value.

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2)
}
```

### When using XCTest

The `expect` function is used in the same way in an `XCTest` environment.

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2)
}
```

## Specifying a Timeout

The `expect` function includes a `timeout` parameter, which specifies the maximum amount of time (in seconds) to wait for the state to finish processing before timing out. The default value is 2 seconds.

### When using Testing

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2, timeout: 0.1)
}
```

### When using XCTest

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2, timeout: 5)
}
```

## Diagnosing Issues

When a test fails, the output provides detailed information about the failure, making it easier to diagnose the issue. Below are example screenshots showing how a failure appears.

### When using Testing

![A screenshot of a test failure in Xcode, showing the expected and actual values.](expect-testing-failure.png)

### When using XCTest

![A screenshot of a test failure in Xcode, showing a descriptive failure message from an XCTest assertion.](expect-xctest-failure.png)
