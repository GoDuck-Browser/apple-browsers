//
//  ContentScopePrivacyConfigurationJsonGenerator.swift
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

public protocol CustomisedPrivacyConfigurationJsonGenerating {
    var privacyConfiguration: Data? { get }
}

public struct ContentScopePrivacyConfigurationJsonGenerator: CustomisedPrivacyConfigurationJsonGenerating {
    let featureFlagger: FeatureFlagger
    let privacyConfigurationManager: PrivacyConfigurationManaging

    public init(featureFlagger: FeatureFlagger, privacyConfigurationManager: PrivacyConfigurationManaging) {
        self.featureFlagger = featureFlagger
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    public var privacyConfiguration: Data? {
        guard let config = try? PrivacyConfigurationData(data: privacyConfigurationManager.currentConfig) else { return nil }

        let newFeatures = self.changeFingerprintingCanvasConfigStateBasedOnCohort(config: config.features)
        let newConfig = PrivacyConfigurationData(features: newFeatures, unprotectedTemporary: config.unprotectedTemporary, trackerAllowlist: config.trackerAllowlist, version: config.version)
        return try? newConfig.toJSONData()
    }

    private func changeFingerprintingCanvasConfigStateBasedOnCohort(config: [PrivacyConfigurationData.FeatureName: PrivacyConfigurationData.PrivacyFeature]) -> [PrivacyConfigurationData.FeatureName: PrivacyConfigurationData.PrivacyFeature] {
        var newConfig = config
        guard let fingerprintingCanvasCohort = featureFlagger.resolveCohort(for: ContentScopeExperimentsFeatureFlags.fingerprintingCanvas) as? ContentScopeExperimentsFeatureFlags.ContentScopeExperimentsCohort
        else {
            return newConfig
        }
        var fingerprintingCanvasState: String {
            switch fingerprintingCanvasCohort {
            case .control:
                "disabled"
            case .treatment:
                "enabled"
            }
        }
        let fingerprintingCanvasConfig = config[PrivacyFeature.fingerprintingCanvas.rawValue]
        let expectations = fingerprintingCanvasConfig?.exceptions ?? []
        let settings = fingerprintingCanvasConfig?.settings ?? [:]
        let features = fingerprintingCanvasConfig?.features ?? [:]
        let minSupportedVersion = fingerprintingCanvasConfig?.minSupportedVersion
        let hash = fingerprintingCanvasConfig?.hash

        newConfig[PrivacyFeature.fingerprintingCanvas.rawValue] = PrivacyConfigurationData.PrivacyFeature(state: fingerprintingCanvasState, exceptions: expectations, settings: settings, features: features, minSupportedVersion: minSupportedVersion, hash: hash)
        return newConfig
    }

}
