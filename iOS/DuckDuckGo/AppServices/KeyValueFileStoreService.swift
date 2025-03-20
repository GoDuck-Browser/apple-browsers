//
//  KeyValueFileStoreService.swift
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

import Persistence
import Foundation

final class KeyValueFileStoreService {

    enum Constants {
        static let testKey = "TestKey"
        static let testValue = "TestValue"
    }

    let keyValueFilesStore: ThrowingKeyValueStoring?

    var initialSaveSucceeded: Bool = false
    var secondReadSucceeded: Bool? = nil

    init() {

        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Pixel 1
            self.keyValueFilesStore = nil
            return
        }

        do {
            let keyValueFilesStore = try KeyValueFileStore(location: appSupportDir, name: "AppKeyValueStore")

            self.keyValueFilesStore = keyValueFilesStore
        } catch {
            self.keyValueFilesStore = nil
            // Pixel 2
        }

        do {
            try self.keyValueFilesStore?.set(Constants.testValue, forKey: Constants.testKey)
            self.initialSaveSucceeded = true
        } catch {
            // Pixel 3
        }

        

    }

    func onForeground() {

    }

    func onBackground() {

    }
}
