//
//  ContentScopeExperimentsFeatureFlags.swift
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

public enum ContentScopeExperimentsFeatureFlags: String, CaseIterable {
    case fingerprintingCanvas

    public var subfeature: any PrivacySubfeature {
        switch self {
        case .fingerprintingCanvas:
            ContentScopeExperimentsSubfeatures.fingerprintingCanvasExperiment
        }
    }
}

extension ContentScopeExperimentsFeatureFlags: FeatureFlagDescribing {
    public var supportsLocalOverriding: Bool {
        return true
    }

    public var source: FeatureFlagSource {
        return .remoteReleasable(.subfeature(ContentScopeExperimentsSubfeatures.fingerprintingCanvasExperiment))
    }

    public var cohortType: (any FeatureFlagCohortDescribing.Type)? {
        return ContentScopeExperimentsCohort.self
    }

    public enum ContentScopeExperimentsCohort: String, FeatureFlagCohortDescribing {
        /// Control cohort with no changes applied.
        case control
        /// Treatment cohort where the experiment modifications are applied.
        case treatment
    }

}
