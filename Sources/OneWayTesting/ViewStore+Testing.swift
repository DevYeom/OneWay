//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay

#if !os(Linux)
#if canImport(Testing)
extension ViewStore {
    #if swift(>=6)
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - fileID: The file ID from which the function is called.
    ///   - filePath: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    ///   - column: The column number from which the function is called.
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: Double = 2,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(
            keyPath,
            input,
            timeout: timeout,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
    #else
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - fileID: The file ID from which the function is called.
    ///   - filePath: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    ///   - column: The column number from which the function is called.
    public func expect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: Double = 2,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(
            keyPath,
            input,
            timeout: timeout,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
    #endif
}
#endif

#if !canImport(Testing) && canImport(XCTest)
extension ViewStore {
    #if swift(>=6)
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - file: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    public func expect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: Double = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(
            keyPath,
            input,
            timeout: timeout,
            file: file,
            line: line
        )
    }
    #else
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - file: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    public func expect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: Double = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(
            keyPath,
            input,
            timeout: timeout,
            file: file,
            line: line
        )
    }
    #endif
}
#endif
#endif
