//
//  ContentScopePrivacyConfigurationJsonGeneratorTests.swift
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

import XCTest
@testable import ContentScopeScripts
import BrowserServicesKit
import Combine

final class ContentScopePrivacyConfigurationJsonGeneratorTests: XCTestCase {

    private var mockPrivacyConfigurationManager: MockPrivacyConfigurationManager!
    private var mockFeatureFlagger: MockFeatureFlagger!

    override func setUp() {
        super.setUp()
        mockPrivacyConfigurationManager = MockPrivacyConfigurationManager()
        mockFeatureFlagger = MockFeatureFlagger()
    }

    let config = """
        {
            "features": {
                "fingerprintingCanvas": {
                    "state": "disabled"
                },
                "contentScopeExperiments": {
                    "exceptions": [],
                    "state": "enabled",
                    "features": {
                        "fingerprintingCanvas": {
                            "state": "enabled",
                            "cohorts": [
                                {
                                    "name": "treatment",
                                    "weight": 1
                                }
                            ]
                        }
                    },
                    "hash": "042cc21dcd61460ea41c394d02c9b2b8"
                }
            }
        }

    """

    func testGeneratorEnablesFeatureForTreatmentCohort() {
        // Arrange: Set up the dummy flagger to return treatment for the experiment.
        mockPrivacyConfigurationManager.currentConfigString = config

        let generator = ContentScopePrivacyConfigurationJsonGenerator(
            featureFlagger: mockFeatureFlagger,
            privacyConfigurationManager: mockPrivacyConfigurationManager
        )
        
        // Act: Generate the JSON configuration.
        guard let data = generator.privacyConfiguration,
              let updatedConfig = try? PrivacyConfigurationData(data: data) else {
            XCTFail("Failed to generate configuration JSON")
            return
        }
        
        // Assert: The fingerprintingCanvas feature should now be enabled.
        if let updatedFeature = updatedConfig.features["fingerprintingCanvas"] {
            XCTAssertEqual(updatedFeature.state, "enabled", "The feature state should be enabled for treatment cohort")
        } else {
            XCTFail("The fingerprintingCanvas feature is missing in the updated configuration")
        }
    }
    
}

final class MockFeatureFlagger: FeatureFlagger {
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
    var localOverrides: FeatureFlagLocalOverriding?
    var disabledFlags: [String] = []


    var allActiveExperiments: Experiments {
        return [:]
    }

    func isFeatureOn<Flag>(for featureFlag: Flag, allowOverride: Bool) -> Bool where Flag : FeatureFlagDescribing {
        if disabledFlags.contains(featureFlag.rawValue) {
            return false
        }
        return true
    }

    func resolveCohort<Flag>(for featureFlag: Flag, allowOverride: Bool) -> (any FeatureFlagCohortDescribing)? where Flag : FeatureFlagDescribing {
        return ContentScopeExperimentsFeatureFlags.ContentScopeExperimentsCohort.treatment
    }

}

final class MockInternalUserStoring: InternalUserStoring {
    var isInternalUser: Bool = false
}

class MockPrivacyConfigurationManager: NSObject, PrivacyConfigurationManaging {
    var currentConfigString: String = ""

    var embeddedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData {
        fatalError("not implemented")
    }

    var fetchedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData? {
        fatalError("not implemented")
    }

    var currentConfig: Data {
        Data(base64Encoded: currentConfigString)!
    }

    func reload(etag: String?, data: Data?) -> BrowserServicesKit.PrivacyConfigurationManager.ReloadResult {
        fatalError("not implemented")
    }

    var updatesPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()
    var privacyConfig: PrivacyConfiguration = MockPrivacyConfiguration()
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider()
}

class MockPrivacyConfiguration: PrivacyConfiguration {

    var isSubfeatureKeyEnabled: ((any PrivacySubfeature, AppVersionProvider) -> Bool)?
    func isSubfeatureEnabled(_ subfeature: any PrivacySubfeature, versionProvider: AppVersionProvider, randomizer: (Range<Double>) -> Double) -> Bool {
        isSubfeatureKeyEnabled?(subfeature, versionProvider) ?? false
    }

    func stateFor(_ subfeature: any PrivacySubfeature, versionProvider: AppVersionProvider, randomizer: (Range<Double>) -> Double) -> PrivacyConfigurationFeatureState {
        if isSubfeatureKeyEnabled?(subfeature, versionProvider) == true {
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

    var identifier: String = "MockPrivacyConfiguration"
    var version: String? = "123456789"
    var userUnprotectedDomains: [String] = []
    var tempUnprotectedDomains: [String] = []
    var trackerAllowlist: PrivacyConfigurationData.TrackerAllowlist = .init(entries: [:],
                                                                            state: PrivacyConfigurationData.State.enabled)
    var exceptionsList: (PrivacyFeature) -> [String] = { _ in [] }
    var featureSettings: PrivacyConfigurationData.PrivacyFeature.FeatureSettings = [:]

    var subfeatureSettings: String?
    var mockSubfeatureSettings: [String: String] = [:]
    func settings(for subfeature: any PrivacySubfeature) -> PrivacyConfigurationData.PrivacyFeature.SubfeatureSettings? {
        return subfeatureSettings ?? mockSubfeatureSettings[subfeature.rawValue]
    }

    func exceptionsList(forFeature featureKey: PrivacyFeature) -> [String] { exceptionsList(featureKey) }
    var isFeatureKeyEnabled: ((PrivacyFeature, AppVersionProvider) -> Bool)?
    func isEnabled(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> Bool {
        isFeatureKeyEnabled?(featureKey, versionProvider) ?? true
    }
    func stateFor(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> PrivacyConfigurationFeatureState {
        if isFeatureKeyEnabled?(featureKey, versionProvider) == true {
            return .enabled
        }
        return .disabled(.disabledInConfig)
    }

    func isFeature(_ feature: PrivacyFeature, enabledForDomain: String?) -> Bool { true }
    func isProtected(domain: String?) -> Bool { true }
    func isUserUnprotected(domain: String?) -> Bool { false }
    func isTempUnprotected(domain: String?) -> Bool { false }
    func isInExceptionList(domain: String?, forFeature featureKey: PrivacyFeature) -> Bool { false }
    func settings(for feature: PrivacyFeature) -> PrivacyConfigurationData.PrivacyFeature.FeatureSettings { featureSettings }
    func userEnabledProtection(forDomain: String) {}
    func userDisabledProtection(forDomain: String) {}
}

extension DefaultInternalUserDecider {
    convenience init(mockedStore: MockInternalUserStoring = MockInternalUserStoring()) {
        self.init(store: mockedStore)
    }
}
