//
//  ConfigurationManager.swift
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
import BrowserServicesKit
import Persistence
import Configuration
import Common
import Networking
import PixelKit
import DataBrokerProtectionCore

public extension Logger {
    static var config: Logger = { Logger(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Configuration") }()
}

public final class ConfigurationManager: DefaultConfigurationManager {

    private let privacyConfigManager: DBPPrivacyConfigurationManager

    public init(privacyConfigManager: DBPPrivacyConfigurationManager,
                fetcher: ConfigurationFetching = ConfigurationFetcher(store: ConfigurationStore(), eventMapping: configurationDebugEvents),
                store: ConfigurationStoring = ConfigurationStore(),
                defaults: KeyValueStoring = UserDefaults.config) {
        self.privacyConfigManager = privacyConfigManager
        super.init(fetcher: fetcher, store: store, defaults: defaults)
    }

    public static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: DataBrokerProtectionMacOSPixels
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .invalidPayload(configuration)
        }

        PixelKit.fire(DebugEvent(domainEvent, error: error))
    }

    func log() {
        Logger.config.log("last update \(String(describing: self.lastUpdateTime), privacy: .public)")
        Logger.config.log("last refresh check \(String(describing: self.lastRefreshCheckTime), privacy: .public)")
    }

    override public func refreshNow(isDebug: Bool = false) async {
        let updateConfigDependenciesTask = Task {
            let didFetchConfig = await fetchConfigDependencies(isDebug: isDebug)
            if didFetchConfig {
                updateConfigDependencies()
                tryAgainLater()
            }
        }

        await updateConfigDependenciesTask.value

        (store as? ConfigurationStore)?.log()
        log()
    }

    func fetchConfigDependencies(isDebug: Bool) async -> Bool {
        do {
            try await fetcher.fetch(.privacyConfiguration, isDebug: isDebug)
            return true
        } catch {
            Logger.config.error(
                "Failed to complete configuration update to \(Configuration.privacyConfiguration.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            tryAgainSoon()
        }

        return false
    }

    func updateConfigDependencies() {
        privacyConfigManager.reload(
            etag: store.loadEtag(for: .privacyConfiguration),
            data: store.loadData(for: .privacyConfiguration)
        )
    }
}

extension ConfigurationManager {
    public override var presentedItemURL: URL? {
        store.fileUrl(for: .privacyConfiguration).deletingLastPathComponent()
    }

    public override func presentedSubitemDidAppear(at url: URL) {
        guard url == store.fileUrl(for: .privacyConfiguration) else { return }
        updateConfigDependencies()
    }

    public override func presentedSubitemDidChange(at url: URL) {
        guard url == store.fileUrl(for: .privacyConfiguration) else { return }
        updateConfigDependencies()
    }
}
