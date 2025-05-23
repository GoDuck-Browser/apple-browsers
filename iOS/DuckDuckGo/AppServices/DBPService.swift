//
//  DBPService.swift
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

import DataBrokerProtectionCore
import DataBrokerProtection_iOS
import Core
import Common
import BrowserServicesKit
import PixelKit

final class DBPService: NSObject {

    private let dbpIOSManager: DataBrokerProtectionIOSManager?

    init(appDependencies: DependencyProvider) {
#if DEBUG || ALPHA
        let dbpSubscriptionManager = DataBrokerProtectionSubscriptionManager(subscriptionManager: AppDependencyProvider.shared.subscriptionAuthV1toV2Bridge,
                                                                          runTypeProvider: appDependencies.dbpSettings,
                                                                          isAuthV2Enabled: appDependencies.isAuthV2Enabled)
        let authManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: dbpSubscriptionManager)
        let featureFlagger = DBPFeatureFlagger(appDependencies: appDependencies)

        if let pixelKit = PixelKit.shared {
            self.dbpIOSManager = DataBrokerProtectionIOSManagerProvider.iOSManager(
                authenticationManager: authManager,
                privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager,
                featureFlagger: featureFlagger,
                pixelKit: pixelKit)

            DataBrokerProtectionIOSManager.shared = self.dbpIOSManager
        } else {
            assertionFailure("PixelKit not set up")
            self.dbpIOSManager = nil
        }
#else
        self.dbpIOSManager = nil
#endif
        super.init()
    }

    func onBackground() {
        dbpIOSManager?.scheduleBGProcessingTask()
    }
}

private final class DBPFeatureFlagger: RemoteBrokerDeliveryFeatureFlagging {
    private let appDependencies: DependencyProvider

    var isRemoteBrokerDeliveryFeatureOn: Bool {
        appDependencies.featureFlagger.isFeatureOn(.dbpRemoteBrokerDelivery)
    }

    init(appDependencies: DependencyProvider) {
        self.appDependencies = appDependencies
    }
}
