//
//  AIChatMenuVisibilityConfigurable.swift
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

import Combine
import BrowserServicesKit

protocol AIChatMenuVisibilityConfigurable {

    /// This property validates remote feature flags and user settings to determine if the shortcut
    /// should be presented to the user.
    ///
    /// - Returns: `true` if the application menu shortcut should be displayed; otherwise, `false`.
    var shouldDisplayApplicationMenuShortcut: Bool { get }

    /// This property reflects the current state of the feature flag for the application menu shortcut.
    ///
    /// - Returns: `true` if the remote feature for the application menu shortcut is enabled; otherwise, `false`.
    var isFeatureEnabledForApplicationMenuShortcut: Bool { get }


    /// A publisher that emits a value when either the `shouldDisplayApplicationMenuShortcut`  settings, backed by storage, are changed.
    ///
    /// This allows subscribers to react to changes in the visibility settings of the application menu
    /// and toolbar shortcuts.
    ///
    /// - Returns: A `PassthroughSubject` that emits `Void` when the values change.
    var valuesChangedPublisher: PassthroughSubject<Void, Never> { get }
}

final class AIChatMenuConfiguration: AIChatMenuVisibilityConfigurable {

    enum ShortcutType {
        case applicationMenu
        case toolbar
    }

    private var cancellables = Set<AnyCancellable>()
    private var storage: AIChatPreferencesStorage
    private let notificationCenter: NotificationCenter
    private let remoteSettings: AIChatRemoteSettingsProvider

    var valuesChangedPublisher = PassthroughSubject<Void, Never>()

    var isFeatureEnabledForApplicationMenuShortcut: Bool {
        isFeatureEnabledFor(shortcutType: .applicationMenu)
    }

    var shouldDisplayApplicationMenuShortcut: Bool {
        return isFeatureEnabledForApplicationMenuShortcut && storage.showShortcutInApplicationMenu
    }

    init(storage: AIChatPreferencesStorage = DefaultAIChatPreferencesStorage(),
         notificationCenter: NotificationCenter = .default,
         remoteSettings: AIChatRemoteSettingsProvider = AIChatRemoteSettings()) {
        self.storage = storage
        self.notificationCenter = notificationCenter
        self.remoteSettings = remoteSettings

        self.subscribeToValuesChanged()
    }

    private func subscribeToValuesChanged() {
        storage.showShortcutInApplicationMenuPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send()
            }.store(in: &cancellables)
    }

    private func isFeatureEnabledFor(shortcutType: ShortcutType) -> Bool {
        switch shortcutType {
        case .applicationMenu:
            return remoteSettings.isApplicationMenuShortcutEnabled
        case .toolbar:
            return remoteSettings.isToolbarShortcutEnabled
        }
    }
}
