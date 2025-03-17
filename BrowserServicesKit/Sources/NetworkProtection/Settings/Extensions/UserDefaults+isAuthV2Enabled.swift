//
//  UserDefaults+disableRekeying.swift
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

import Combine
import Foundation

extension UserDefaults {
    private var isAuthV2EnabledKey: String {
        "networkProtectionSettingIsAuthV2Enabled"
    }

    static let isAuthV2EnabledDefaultValue = false

    @objc
    dynamic var networkProtectionSettingIsAuthV2Enabled: Bool {
        get {
            value(forKey: isAuthV2EnabledKey) as? Bool ?? Self.isAuthV2EnabledDefaultValue
        }

        set {
            set(newValue, forKey: isAuthV2EnabledKey)
        }
    }

    var networkProtectionSettingIsAuthV2EnabledPublisher: AnyPublisher<Bool, Never> {
        publisher(for: \.networkProtectionSettingIsAuthV2Enabled).eraseToAnyPublisher()
    }

    func resetNetworkProtectionSettingIsAuthV2Enabled() {
        removeObject(forKey: isAuthV2EnabledKey)
    }
}
