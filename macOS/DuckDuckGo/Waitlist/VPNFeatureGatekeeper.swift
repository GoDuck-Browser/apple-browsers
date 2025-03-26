//
//  VPNFeatureGatekeeper.swift
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

import BrowserServicesKit
import Combine
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionUI
import LoginItems
import PixelKit
import Subscription

protocol VPNFeatureGatekeeper {
    var isInstalled: Bool { get }

    func canStartVPN() async throws -> Bool
    func isVPNVisible() -> Bool
    func shouldUninstallAutomatically() async -> Bool
    func disableIfUserHasNoAccess() async

    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> { get }
}

struct DefaultVPNFeatureGatekeeper: VPNFeatureGatekeeper {

    private static var subscriptionAuthTokenPrefix: String { "ddg:" }
    private let vpnUninstaller: VPNUninstalling
    private let defaults: UserDefaults
    private let subscriptionManager: any SubscriptionAuthV1toV2Bridge

    init(vpnUninstaller: VPNUninstalling = VPNUninstaller(),
         defaults: UserDefaults = .netP,
         subscriptionManager: any SubscriptionAuthV1toV2Bridge) {
        self.vpnUninstaller = vpnUninstaller
        self.defaults = defaults
        self.subscriptionManager = subscriptionManager
    }

    var isInstalled: Bool {
        LoginItem.vpnMenu.status.isInstalled
    }

    /// Whether the user can start the VPN.
    ///
    func canStartVPN() async throws -> Bool {
        try await subscriptionManager.isEnabled(feature: .networkProtection)
    }

    /// Whether the VPN is installed for the user, regardless of entitlements.
    ///
    func isVPNVisible() -> Bool {
        LoginItem.vpnMenu.status.isInstalled
    }

    /// Returns whether the VPN should be uninstalled automatically.
    ///
    /// This is only `true` when we know the user has no permission to start the VPN
    ///
    func shouldUninstallAutomatically() async -> Bool {
        guard let canStartVPN = try? await canStartVPN() else {
            return false
        }

        return !canStartVPN && isVPNVisible()
    }

    /// Whether the user is fully onboarded
    /// 
    var isOnboarded: Bool {
        defaults.networkProtectionOnboardingStatus == .completed
    }

    /// A publisher for the onboarding status
    ///
    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> {
        defaults.networkProtectionOnboardingStatusPublisher
    }

    /// A method meant to be called safely from different places to disable the VPN if the user isn't meant to have access to it.
    ///
    func disableIfUserHasNoAccess() async {
        guard await shouldUninstallAutomatically() else {
            return
        }

        /// There's not much to be done for this error here.
        /// The uninstall call already fires pixels to allow us to anonymously track success rate and see the errors.
        try? await vpnUninstaller.uninstall(removeSystemExtension: false)
    }
}
