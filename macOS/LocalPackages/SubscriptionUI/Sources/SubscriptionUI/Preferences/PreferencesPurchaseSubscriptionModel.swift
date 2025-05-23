//
//  PreferencesPurchaseSubscriptionModel.swift
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

import AppKit
import Subscription
import struct Combine.AnyPublisher
import enum Combine.Publishers
import FeatureFlags
import BrowserServicesKit
import os.log

public final class PreferencesPurchaseSubscriptionModel: ObservableObject {

    @Published var subscriptionStorefrontRegion: SubscriptionRegion = .usa

    var currentPurchasePlatform: SubscriptionEnvironment.PurchasePlatform { subscriptionManager.currentEnvironment.purchasePlatform }

    lazy var sheetModel = SubscriptionAccessViewModel(actionHandlers: sheetActionHandler,
                                                      purchasePlatform: subscriptionManager.currentEnvironment.purchasePlatform)

    var shouldDirectlyLaunchActivationFlow: Bool {
        subscriptionManager.currentEnvironment.purchasePlatform == .stripe
    }

    private let subscriptionManager: SubscriptionAuthV1toV2Bridge
    private let userEventHandler: (PreferencesPurchaseSubscriptionModel.UserEvent) -> Void
    private let sheetActionHandler: SubscriptionAccessActionHandlers

    public enum UserEvent {
        case didClickIHaveASubscription,
             openURL(SubscriptionURL)
    }

    public init(subscriptionManager: SubscriptionAuthV1toV2Bridge,
                userEventHandler: @escaping (PreferencesPurchaseSubscriptionModel.UserEvent) -> Void,
                sheetActionHandler: SubscriptionAccessActionHandlers) {
        self.subscriptionManager = subscriptionManager
        self.userEventHandler = userEventHandler
        self.sheetActionHandler = sheetActionHandler
        self.subscriptionStorefrontRegion = currentStorefrontRegion()
    }

    @MainActor
    func didAppear() {
        self.subscriptionStorefrontRegion = currentStorefrontRegion()
    }

    @MainActor
    func purchaseAction() {
        userEventHandler(.openURL(.purchase))
    }

    @MainActor
    func didClickIHaveASubscription() {
        userEventHandler(.didClickIHaveASubscription)
    }

    @MainActor
    func openFAQ() {
        userEventHandler(.openURL(.faq))
    }

    @MainActor
    func openPrivacyPolicy() {
        userEventHandler(.openURL(.privacyPolicy))
    }

    private func currentStorefrontRegion() -> SubscriptionRegion {
        var region: SubscriptionRegion?

        switch currentPurchasePlatform {
        case .appStore:
            if #available(macOS 12.0, *) {
                if let subscriptionManagerV1 = subscriptionManager as? SubscriptionManager {
                    region = subscriptionManagerV1.storePurchaseManager().currentStorefrontRegion
                } else if let subscriptionManagerV2 = subscriptionManager as? SubscriptionManagerV2 {
                    region = subscriptionManagerV2.storePurchaseManager().currentStorefrontRegion
                }
            }
        case .stripe:
            region = .usa
        }

        return region ?? .usa
    }
}
