//
//  TaskExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

public struct Sleeper {

    public static let `default` = Sleeper(sleep: {
        try await Task<Never, Never>.sleep(interval: $0)
    })

    private let sleep: (TimeInterval) async throws -> Void

    public init(sleep: @escaping (TimeInterval) async throws -> Void) {
        self.sleep = sleep
    }

    @available(macOS 13.0, iOS 16.0, *)
    public init(clock: any Clock<Duration>) {
        self.sleep = { interval in
            try await clock.sleep(for: .nanoseconds(UInt64(interval * Double(NSEC_PER_SEC))))
        }
    }

    public func sleep(for interval: TimeInterval) async throws {
        try await sleep(interval)
    }

}

public func performPeriodicJob(withDelay delay: TimeInterval? = nil,
                               interval: TimeInterval,
                               sleeper: Sleeper = .default,
                               operation: @escaping @Sendable () async throws -> Void,
                               cancellationHandler: (@Sendable () async -> Void)? = nil) async throws -> Never {

    do {
        if let delay {
            try await sleeper.sleep(for: delay)
        }

        repeat {
            try await operation()

            try await sleeper.sleep(for: interval)
        } while true
    } catch let error as CancellationError {
        await cancellationHandler?()
        throw error
    }
}

public extension Task where Success == Never, Failure == Error {

    static func periodic(delay: TimeInterval? = nil,
                         interval: TimeInterval,
                         sleeper: Sleeper = .default,
                         operation: @escaping @Sendable () async -> Void,
                         cancellationHandler: (@Sendable () async -> Void)? = nil) -> Task {

        return periodic(delay: delay, interval: interval, sleeper: sleeper, operation: { await operation() } as @Sendable () async throws -> Void, cancellationHandler: cancellationHandler)
    }

    static func periodic(delay: TimeInterval? = nil,
                         interval: TimeInterval,
                         sleeper: Sleeper = .default,
                         operation: @escaping @Sendable () async throws -> Void,
                         cancellationHandler: (@Sendable () async -> Void)? = nil) -> Task {

        Task {
            try await performPeriodicJob(withDelay: delay, interval: interval, sleeper: sleeper, operation: operation, cancellationHandler: cancellationHandler)
        }
    }
}

public extension Task where Success == Never, Failure == Never {

    static func sleep(interval: TimeInterval) async throws {
        assert(interval > 0)
        try await Task<Never, Never>.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
    }

}
