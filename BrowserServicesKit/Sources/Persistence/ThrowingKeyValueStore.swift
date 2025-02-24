//
//  ThrowingKeyValueStore.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

public protocol ThrowingKeyValueStore {

    /// Set a value for a given key and persist it
    func set(_ value: Any, forKey key: String) throws

    /// Retrieve a value for a given key
    func get<T>(_ key: String) -> T?

    /// Remove a key-value pair
    func remove(_ key: String) throws
}

extension KeyValueStoring where Self: ThrowingKeyValueStore {

    public func object(forKey defaultName: String) -> Any? {
        return get(defaultName) as Any?
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        do {
            if let value = value {
                try set(value, forKey: defaultName)
            } else {
                try remove(defaultName)
            }
        } catch {
            assertionFailure("Error setting key '\(defaultName)': \(error)")
        }
    }

    public func removeObject(forKey defaultName: String) {
        do {
            try (self as ThrowingKeyValueStore).remove(defaultName)
        } catch {
            assertionFailure("Error removing key '\(defaultName)': \(error)")
        }
    }
}
