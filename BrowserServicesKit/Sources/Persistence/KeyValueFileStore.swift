//
//  KeyValueFileStore.swift
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


import Foundation

// Basic Key-Value store using file as a persistence.
// Supports Data,
//
// Limitations:
//   - Sharing same file between processes is currently not supported (need to add dispatch source for monitoring such events)
//   - No Codable support but you have Data.
public class KeyValueFileStore: ThrowingKeyValueStoring {

    enum Error: Swift.Error {
        case readFailure(Swift.Error)
        case writeFailure(Swift.Error)
        case wrongFormat

        var code: Int {
            switch self {
            case .readFailure:
                return 0
            case .writeFailure:
                return 1
            case .wrongFormat:
                return 2
            }
        }
    }

    private let location: URL
    private let name: String

    private var internalRepresentation: [String: Any]?
    private let lock = NSLock()

    public init(location: URL, name: String,
         protectionType: FileProtectionType = .completeUntilFirstUserAuthentication) {
        self.location = location
        self.name = name
    }

    private func filePath() -> URL {
        return location.appending(name)
    }

    private func persist(dictionary: [String: Any]) throws {
        let location = filePath()

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
            try data.write(to: location)
        } catch {
            throw Error.readFailure(error)
        }
    }

    private func load() throws -> [String: Any] {
        let location = filePath()

        do {
            let data = try Data(contentsOf: location)
            guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                throw Error.wrongFormat
            }

            self.internalRepresentation = dictionary
            return dictionary
        } catch {
            throw Error.readFailure(error)
        }
    }


    public func object(forKey key: String) throws -> Any? {
        lock.lock()
        defer {
            lock.unlock()
        }

        let internalRepresentation = try internalRepresentation ?? load()
        return internalRepresentation[key]
    }

    public func set(_ value: Any?, forKey key: String) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        var dictionary = try internalRepresentation ?? load()
        dictionary[key] = value
        self.internalRepresentation = dictionary
        try persist(dictionary: dictionary)
    }

    public func removeObject(forKey key: String) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        var dictionary = try internalRepresentation ?? load()

        guard dictionary.removeValue(forKey: key) != nil else {
            return
        }
        self.internalRepresentation = dictionary
        try persist(dictionary: dictionary)
    }


    
}
