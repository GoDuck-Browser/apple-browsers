//
//  MockPrivacyConfiguration.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

#if DEBUG

final class MockPrivacyConfiguration: PrivacyConfiguration {

    var isSubfeatureKeyEnabled: ((any PrivacySubfeature, AppVersionProvider) -> Bool)?

    func isSubfeatureEnabled(_ subfeature: any BrowserServicesKit.PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider, randomizer: (Range<Double>) -> Double, defaultValue: Bool) -> Bool {
        isSubfeatureKeyEnabled?(subfeature, versionProvider) ?? false
    }

    func stateFor(_ subfeature: any PrivacySubfeature, versionProvider: AppVersionProvider, randomizer: (Range<Double>) -> Double) -> PrivacyConfigurationFeatureState {
        if isSubfeatureKeyEnabled?(subfeature, versionProvider) == true {
            return .enabled
        }
        return .disabled(.disabledInConfig)
    }

    var identifier: String = "MockPrivacyConfiguration"
    var version: String? = "1234567890"
    var userUnprotectedDomains: [String] = []
    var tempUnprotectedDomains: [String] = []
    var trackerAllowlist: PrivacyConfigurationData.TrackerAllowlist = .init(entries: [:],
                                                                            state: PrivacyConfigurationData.State.enabled)
    var exceptionsList: (PrivacyFeature) -> [String] = { _ in [] }
    var featureSettings: PrivacyConfigurationData.PrivacyFeature.FeatureSettings = [:]
    var subfeatureSettings: PrivacyConfigurationData.PrivacyFeature.SubfeatureSettings?

    func exceptionsList(forFeature featureKey: PrivacyFeature) -> [String] { exceptionsList(featureKey) }
    var isFeatureKeyEnabled: ((PrivacyFeature, AppVersionProvider) -> Bool)?
    func isEnabled(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> Bool {
        isEnabled(featureKey: featureKey, versionProvider: versionProvider, defaultValue: false)
    }

    func isEnabled(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider, defaultValue: Bool) -> Bool {
        isFeatureKeyEnabled?(featureKey, versionProvider) ?? true
    }

    func stateFor(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> PrivacyConfigurationFeatureState {
        if isFeatureKeyEnabled?(featureKey, versionProvider) == true {
            return .enabled
        }
        return .disabled(.disabledInConfig)
    }

    func stateFor(subfeatureID: SubfeatureID, parentFeatureID: ParentFeatureID, versionProvider: AppVersionProvider, randomizer: (Range<Double>) -> Double) -> PrivacyConfigurationFeatureState {
        return .disabled(.disabledInConfig)
    }

    func cohorts(for subfeature: any PrivacySubfeature) -> [PrivacyConfigurationData.Cohort]? {
        return nil
    }

    func cohorts(subfeatureID: SubfeatureID, parentFeatureID: ParentFeatureID) -> [PrivacyConfigurationData.Cohort]? {
        return nil
    }

    func isFeature(_ feature: PrivacyFeature, enabledForDomain: String?) -> Bool { true }
    func isProtected(domain: String?) -> Bool { true }
    func isUserUnprotected(domain: String?) -> Bool { false }
    func isTempUnprotected(domain: String?) -> Bool { false }
    func isInExceptionList(domain: String?, forFeature featureKey: PrivacyFeature) -> Bool { false }
    func settings(for feature: PrivacyFeature) -> PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        featureSettings }
    func settings(for subfeature: any BrowserServicesKit.PrivacySubfeature) -> PrivacyConfigurationData.PrivacyFeature.SubfeatureSettings? {
        subfeatureSettings
    }
    func userEnabledProtection(forDomain: String) {}
    func userDisabledProtection(forDomain: String) {}
}

final class MockInternalUserStoring: InternalUserStoring {
    var isInternalUser: Bool = false
}

extension DefaultInternalUserDecider {
    convenience init(mockedStore: MockInternalUserStoring = MockInternalUserStoring()) {
        self.init(store: mockedStore)
    }
}

final class MockPrivacyConfigurationManager: NSObject, PrivacyConfigurationManaging {
    var embeddedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData {
        fatalError("not implemented")
    }

    var fetchedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData? {
        fatalError("not implemented")
    }

    var currentConfig: Data {
        Data()
    }

    func reload(etag: String?, data: Data?) -> BrowserServicesKit.PrivacyConfigurationManager.ReloadResult {
        return .embedded
    }

    var updatesPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()
    var mockPrivacyConfig = MockPrivacyConfiguration()
    var privacyConfig: PrivacyConfiguration {
        mockPrivacyConfig
    }
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider()
}

#endif
