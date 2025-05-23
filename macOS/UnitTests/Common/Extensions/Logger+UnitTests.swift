//
//  Logger+UnitTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import os.log

public extension Logger {
    fileprivate static let subsystem = "com.duckduckgo.macos.browser.DuckDuckGoTests"

    static var tests = { Logger(subsystem: subsystem, category: "🧪") }()
}

infix operator ???: NilCoalescingPrecedence
/// Provide value debug description or ??? "defaultValue" - to be used for logging like:
/// ```
/// Logger.general.debug("event received: \(event ??? "<nil>")")
/// ```
public func ??? <T>(optionalValue: T?, defaultValue: @autoclosure () -> String) -> String {
    optionalValue.map { String(describing: $0) } ?? defaultValue()
}
