//
//  PropertyListKeyValueStore.swift
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


import Foundation

public enum PropertyListKeyValueStoreError: Error {
    case initError(underlyingError: Swift.Error?)
    case storageError(underlyingError: Swift.Error)
    case deletionError(underlyingError: Swift.Error)
}

public final class PropertyListKeyValueStore: ThrowingKeyValueStore {
    typealias InternalError = PropertyListKeyValueStoreError

    private let storeActor: PropertyListKeyValueStoreActor

    // TODO: Do we want to avoid this? Could possibly initialise and store on AppDelegate (or equivalent lifecycle dependency)
    public static let standard: PropertyListKeyValueStore = {
        do {
            return try PropertyListKeyValueStore()
        } catch {
            // TODO: More graceful failure handling. Throwing function instead of property?
            fatalError("Failed to initialize PropertyListKeyValueStore: \(error)")
        }
    }()

    /// Synchronously initializes the store by waiting for the actor to be ready.
    public init(filename: String = "PropertyListStore.plist") throws {
        let group = DispatchGroup()
        var initError: InternalError?
        var actorInstance: PropertyListKeyValueStoreActor?
        group.enter()
        Task {
            do {
                let actor = try await PropertyListKeyValueStoreActor(filename: filename)
                actorInstance = actor
            } catch {
                initError = InternalError.initError(underlyingError: error)
            }
            group.leave()
        }
        group.wait()
        if let error = initError {
            throw error
        }
        guard let instance = actorInstance else {
            throw InternalError.initError(underlyingError: InternalError.initError(underlyingError: nil))
        }
        self.storeActor = instance
    }

    /// Synchronously sets a value for a given key.
    public func set(_ value: Any, forKey key: String) throws {
        let group = DispatchGroup()
        var opError: InternalError?
        group.enter()
        Task {
            do {
                try await storeActor.set(value, forKey: key)
            } catch {
                opError = InternalError.storageError(underlyingError: error)
            }
            group.leave()
        }
        group.wait()
        if let error = opError {
            throw error
        }
    }

    /// Synchronously retrieves a value for a given key.
    public func get<T>(_ key: String) -> T? {
        let group = DispatchGroup()
        var result: T?
        group.enter()
        Task {
            result = await storeActor.get(key)
            group.leave()
        }
        group.wait()
        return result
    }

    /// Synchronously removes a value for a given key.
    public func remove(_ key: String) throws {
        let group = DispatchGroup()
        var opError: InternalError?
        group.enter()
        Task {
            do {
                try await storeActor.remove(key)
            } catch {
                opError = InternalError.storageError(underlyingError: error)
            }
            group.leave()
        }
        group.wait()
        if let error = opError {
            throw error
        }
    }
}

// MARK: - Private Actor Implementation

/// Actor handles all file I/O and in‑memory caching.
/// NSCache is used so that the system can automatically purge entries when needed.
private actor PropertyListKeyValueStoreActor {
    typealias InternalError = PropertyListKeyValueStoreError

    private let fileURL: URL
    private var store: [String: Any] = [:]
    private let cache = NSCache<NSString, AnyObject>()

    /// Initialize the actor by loading data from a property list file.
    init(filename: String = "PropertyListStore.plist") async throws {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw InternalError.initError(underlyingError: nil)
        }
        self.fileURL = documentsDirectory.appendingPathComponent(filename)

        // Load existing data, if present.
        do {
            let data = try Data(contentsOf: fileURL)
            guard let loadedStore = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw InternalError.initError(underlyingError: nil)
            }
            self.store = loadedStore

            // Preload NSCache with the stored values.
            for (key, value) in loadedStore {
                cache.setObject(value as AnyObject, forKey: key as NSString)
            }
        } catch let error as InternalError {
            throw error
        } catch {
            throw InternalError.initError(underlyingError: error)
        }
    }

    /// Set a value for a given key, update the cache, and persist to disk.
    func set(_ value: Any, forKey key: String) async throws {
        store[key] = value
        cache.setObject(value as AnyObject, forKey: key as NSString)
        try await save()
    }

    func get<T>(_ key: String) -> T? {
        if let cached = cache.object(forKey: key as NSString) as? T {
            return cached
        }
        return store[key] as? T
    }

    func remove(_ key: String) async throws {
        store.removeValue(forKey: key)
        cache.removeObject(forKey: key as NSString)
        try await save()
    }

    private func save() async throws {
        let data = try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
        try data.write(to: fileURL, options: .atomic)
    }
}
