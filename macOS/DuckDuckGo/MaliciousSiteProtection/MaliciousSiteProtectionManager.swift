//
//  MaliciousSiteProtectionManager.swift
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

import BrowserServicesKit
import Combine
import Common
import FeatureFlags
import Foundation
import MaliciousSiteProtection
import Networking
import os.log
import PixelKit

extension MaliciousSiteProtectionManager {

    static func fileName(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
        switch (dataType, dataType.threatKind) {
        case (.hashPrefixSet, .phishing): "phishingHashPrefixes.json"
        case (.filterSet, .phishing): "phishingFilterSet.json"
        case (.hashPrefixSet, .malware): "malwareHashPrefixes.json"
        case (.filterSet, .malware): "malwareFilterSet.json"
        case (.hashPrefixSet, .scam): "scamHashPrefixes.json"
        case (.filterSet, .scam): "scamFilterSet.json"
        }
    }

    static func updateInterval(for dataKind: MaliciousSiteProtection.DataManager.StoredDataType) -> TimeInterval? {
        switch dataKind {
        case .hashPrefixSet: .minutes(20)
        case .filterSet: .hours(12)
        }
    }

    struct EmbeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding {

        private enum Constants {
            static let embeddedDataRevision = 1722371
            static let phishingEmbeddedHashPrefixDataSHA = "96e02c6db46c3366d6cf01ddb73a6659706aa1880fd587d3f86ef002b338b7e9"
            static let phishingEmbeddedFilterSetDataSHA = "ad9bc67df0d7d98bd8e90a9f3b98acf2b4984475834c40cb382b2b7b2d9f8986"
            static let malwareEmbeddedHashPrefixDataSHA = "d892fe0cd99569e91e26d0d3fbfd2b7283d05c5ad0b7f68242699cfddea844c4"
            static let malwareEmbeddedFilterSetDataSHA = "810c0a2825e75810a7a8ad52b3cf7b68168b44f09227c39ce12b4de6432d3e70"
            static let scamEmbeddedHashPrefixDataSHA = "71816131c9eed5e2f63274c05fa4327bb74f380a0d9bf216f5e9dfb2b92730fe"
            static let scamEmbeddedFilterSetDataSHA = "f623af43429ec10a1cbc2c7052f1887196e895f688e4238b5abd2264567e0873"
        }

        func revision(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> Int {
            Constants.embeddedDataRevision
        }

        func url(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> URL {
            let fileName = fileName(for: dataType)
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                fatalError("Could not find embedded data file \"\(fileName)\"")
            }
            return url
        }

        func hash(for dataType: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
            switch (dataType, dataType.threatKind) {
            case (.hashPrefixSet, .phishing): Constants.phishingEmbeddedHashPrefixDataSHA
            case (.filterSet, .phishing): Constants.phishingEmbeddedFilterSetDataSHA
            case (.hashPrefixSet, .malware): Constants.malwareEmbeddedHashPrefixDataSHA
            case (.filterSet, .malware): Constants.malwareEmbeddedFilterSetDataSHA
            case (.hashPrefixSet, .scam): Constants.scamEmbeddedHashPrefixDataSHA
            case (.filterSet, .scam): Constants.scamEmbeddedFilterSetDataSHA
            }
        }

        // see `EmbeddedThreatDataProviding.swift` extension for `EmbeddedThreatDataProviding.load` method implementation
    }
}

// API Environment for testing:
/*
private struct MaliciousSiteTestEnvironment: MaliciousSiteProtection.APIClientEnvironment {
    func headers(for requestType: APIRequestType, platform: MaliciousSiteDetector.APIEnvironment.Platform, authToken: String?) -> APIRequestV2.HeadersV2 {
        MaliciousSiteDetector.APIEnvironment.production.headers(for: requestType, platform: platform, authToken: authToken)
    }
    func url(for requestType: APIRequestType, platform: MaliciousSiteDetector.APIEnvironment.Platform) -> URL {
        MaliciousSiteDetector.APIEnvironment.production.url(for: requestType, platform: platform)
        // append to always make non-cached API request
            .appendingParameter(name: "no_cache", value: String(Int.random(in: 0...10000000)))
    }
    func timeout(for requestType: APIRequestType) -> TimeInterval? {
        switch requestType {
        case .hashPrefixSet, .filterSet:
            MaliciousSiteDetector.APIEnvironment.production.timeout(for: requestType)
        case .matches:
            // used to simulate Matches API timeout
            0.0001
        }
    }
}
*/

public class MaliciousSiteProtectionManager: MaliciousSiteDetecting {
    static let shared = MaliciousSiteProtectionManager()

    private let detector: MaliciousSiteDetecting
    private let updateManager: MaliciousSiteProtection.UpdateManager
    private let detectionPreferences: MaliciousSiteProtectionPreferences
    private let featureFlags: MaliciousSiteProtectionFeatureFlagger

    private var featureFlagsCancellable: AnyCancellable?
    private var detectionPreferencesEnabledCancellable: AnyCancellable?
    private var updateTask: Task<Void, Error>?
    var backgroundUpdatesEnabled: Bool { updateTask != nil }

    init(
        apiEnvironment: MaliciousSiteProtection.APIClientEnvironment? = nil,
        apiService: APIService = DefaultAPIService(urlSession: .shared),
        embeddedDataProvider: MaliciousSiteProtection.EmbeddedDataProviding? = nil,
        dataManager: MaliciousSiteProtection.DataManager? = nil,
        detector: MaliciousSiteProtection.MaliciousSiteDetecting? = nil,
        detectionPreferences: MaliciousSiteProtectionPreferences = MaliciousSiteProtectionPreferences.shared,
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
        configManager: PrivacyConfigurationManaging? = nil,
        updateIntervalProvider: UpdateManager.UpdateIntervalProvider? = nil
    ) {
        self.featureFlags = featureFlagger.maliciousSiteProtectionFeatureFlags()

        let embeddedDataProvider = embeddedDataProvider ?? EmbeddedDataProvider()
        let dataManager = dataManager ?? {
            let configurationUrl = FileManager.default.configurationDirectory()
            let fileStore = MaliciousSiteProtection.FileStore(dataStoreURL: configurationUrl)
            return MaliciousSiteProtection.DataManager(fileStore: fileStore, embeddedDataProvider: embeddedDataProvider, fileNameProvider: Self.fileName(for:))
        }()

        let supportedThreatsProvider = {
            let isScamProtectionEnabled = featureFlagger.isFeatureOn(.scamSiteProtection)
            return isScamProtectionEnabled ? ThreatKind.allCases : ThreatKind.allCases.filter { $0 != .scam }
        }
        let apiEnvironment = apiEnvironment ?? MaliciousSiteDetector.APIEnvironment.production
        self.detector = detector ?? MaliciousSiteDetector(apiEnvironment: apiEnvironment, service: apiService, dataManager: dataManager, eventMapping: Self.debugEvents, supportedThreatsProvider: supportedThreatsProvider)
        self.updateManager = MaliciousSiteProtection.UpdateManager(apiEnvironment: apiEnvironment, service: apiService, dataManager: dataManager, eventMapping: Self.debugEvents, updateIntervalProvider: updateIntervalProvider ?? Self.updateInterval, supportedThreatsProvider: supportedThreatsProvider)
        self.detectionPreferences = detectionPreferences

        self.setupBindings()
    }

    private static let debugEvents = EventMapping<MaliciousSiteProtection.Event> { event, _, _, _ in
        switch event {
        case .errorPageShown,
             .visitSite,
             .iframeLoaded,
             .settingToggled,
             .matchesApiTimeout:
            PixelKit.fire(event)
        case .failedToDownloadInitialDataSets:
            PixelKit.fire(DebugEvent(event), frequency: .dailyAndCount)
        case .matchesApiFailure(let error):
            Logger.maliciousSiteProtection.error("Error fetching matches from API: \(error)")
        }
    }

    private func setupBindings() {
        guard featureFlags.isMaliciousSiteProtectionEnabled else { return }
        subscribeToDetectionPreferences()
    }

    private func subscribeToDetectionPreferences() {
        detectionPreferencesEnabledCancellable = detectionPreferences.$isEnabled
            .sink { [weak self] isEnabled in
                self?.handleIsEnabledChange(enabled: isEnabled)
            }
    }

    private func handleIsEnabledChange(enabled: Bool) {
        if enabled {
            startUpdateTasks()
        } else {
            stopUpdateTasks()
        }
    }

    private func startUpdateTasks() {
        self.updateTask = updateManager.startPeriodicUpdates()
    }

    private func stopUpdateTasks() {
        updateTask?.cancel()
        updateTask = nil
    }

    // MARK: - Public

    public func evaluate(_ url: URL) async -> ThreatKind? {
        guard detectionPreferences.isEnabled,
              featureFlags.shouldDetectMaliciousThreat(forDomain: url.host) else { return .none }

        return await detector.evaluate(url)
    }

}

extension FeatureFlagger {
    func maliciousSiteProtectionFeatureFlags(configManager: PrivacyConfigurationManaging? = nil) -> MaliciousSiteProtectionFeatureFlags {
        let configManager = configManager ?? AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager
        return .init(privacyConfigManager: configManager,
                     isMaliciousSiteProtectionEnabled: { self.isFeatureOn(.maliciousSiteProtection) })
    }
}
