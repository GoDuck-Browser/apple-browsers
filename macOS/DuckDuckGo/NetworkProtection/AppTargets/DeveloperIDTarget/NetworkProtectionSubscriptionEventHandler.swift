//
//  NetworkProtectionSubscriptionEventHandler.swift
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
import Common
import Foundation
import Subscription
import NetworkProtection
import NetworkProtectionUI
import os.log

final class NetworkProtectionSubscriptionEventHandler {

    private let subscriptionManager: any SubscriptionAuthV1toV2Bridge
    private let tunnelController: TunnelController
    private let vpnUninstaller: VPNUninstalling
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(subscriptionManager: any SubscriptionAuthV1toV2Bridge,
         tunnelController: TunnelController,
         vpnUninstaller: VPNUninstalling,
         userDefaults: UserDefaults = .netP) {
        self.subscriptionManager = subscriptionManager
        self.tunnelController = tunnelController
        self.vpnUninstaller = vpnUninstaller
        self.userDefaults = userDefaults

        subscribeToEntitlementChanges()
    }

    private func subscribeToEntitlementChanges() {
        Task {

            if let hasEntitlements = try? await subscriptionManager.isEnabled(feature: .networkProtection) {
                Task {
                    await handleEntitlementsChange(hasEntitlements: hasEntitlements)
                }
            }

            NotificationCenter.default
                .publisher(for: .entitlementsDidChange)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    Logger.networkProtection.log("Entitlements did change notification received")
                    guard let self else {
                        return
                    }

                    guard let entitlements = notification.userInfo?[UserDefaultsCacheKey.subscriptionEntitlements] as? [Entitlement] else {
                        assertionFailure("Missing entitlements are truly unexpected")
                        return
                    }

                    let hasEntitlements = entitlements.contains { entitlement in
                        entitlement.product == .networkProtection
                    }

                    Task {
                        await self.handleEntitlementsChange(hasEntitlements: hasEntitlements)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func handleEntitlementsChange(hasEntitlements: Bool) async {
        if hasEntitlements {
            UserDefaults.netP.networkProtectionEntitlementsExpired = false
        } else {
            await tunnelController.stop()
            UserDefaults.netP.networkProtectionEntitlementsExpired = true
        }
    }

    func registerForSubscriptionAccountManagerEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignIn), name: .accountDidSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidSignOut), name: .accountDidSignOut, object: nil)
    }

    @objc private func handleAccountDidSignIn() {
        guard subscriptionManager.isUserAuthenticated else {
            assertionFailure("[NetP Subscription] AccountManager signed in but token could not be retrieved")
            return
        }
        userDefaults.networkProtectionEntitlementsExpired = false
    }

    @objc private func handleAccountDidSignOut() {
        print("[NetP Subscription] Deleted NetP auth token after signing out from Privacy Pro")

        Task {
            try? await vpnUninstaller.uninstall(removeSystemExtension: false, showNotification: true)
        }
    }

}
