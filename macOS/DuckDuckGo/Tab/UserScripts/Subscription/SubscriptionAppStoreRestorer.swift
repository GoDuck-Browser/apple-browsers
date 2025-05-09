//
//  SubscriptionAppStoreRestorer.swift
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

import AppKit
import Subscription
import SubscriptionUI
import enum StoreKit.StoreKitError
import PixelKit

@available(macOS 12.0, *)
protocol SubscriptionAppStoreRestorer {
    var uiHandler: SubscriptionUIHandling { get }
    func restoreAppStoreSubscription() async
}

@available(macOS 12.0, *)
struct DefaultSubscriptionAppStoreRestorer: SubscriptionAppStoreRestorer {
    private let subscriptionManager: SubscriptionManager
    private let subscriptionErrorReporter: SubscriptionErrorReporter
    private let appStoreRestoreFlow: AppStoreRestoreFlow
    let uiHandler: SubscriptionUIHandling

    public init(subscriptionManager: SubscriptionManager,
                subscriptionErrorReporter: SubscriptionErrorReporter = DefaultSubscriptionErrorReporter(),
                appStoreRestoreFlow: AppStoreRestoreFlow,
                uiHandler: SubscriptionUIHandling) {
        self.subscriptionManager = subscriptionManager
        self.subscriptionErrorReporter = subscriptionErrorReporter
        self.appStoreRestoreFlow = appStoreRestoreFlow
        self.uiHandler = uiHandler
    }

    func restoreAppStoreSubscription() async {
        await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)

        do {
            try await subscriptionManager.storePurchaseManager().syncAppleIDAccount()
            await continueRestore()
        } catch {
            await uiHandler.dismissProgressViewController()

            switch error as? StoreKitError {
            case .some(.userCancelled):
                break
            default:
                let alertResponse = await uiHandler.show(alertType: .appleIDSyncFailed, text: error.localizedDescription)
                if alertResponse == .alertFirstButtonReturn {
                    await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)
                    await continueRestore()
                }
            }
        }
    }

    private func continueRestore() async {
        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
        await uiHandler.dismissProgressViewController()
        switch result {
        case .success:
            PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreSuccess, frequency: .legacyDailyAndCount)
        case .failure(let error):
            switch error {
            case .missingAccountOrTransactions:
                subscriptionErrorReporter.report(subscriptionActivationError: .restoreFailedDueToNoSubscription)
                await showSubscriptionNotFoundAlert()
            case .subscriptionExpired:
                subscriptionErrorReporter.report(subscriptionActivationError: .restoreFailedDueToExpiredSubscription)
                await showSubscriptionInactiveAlert()
            case .failedToObtainAccessToken, .failedToFetchAccountDetails, .failedToFetchSubscriptionDetails:
                subscriptionErrorReporter.report(subscriptionActivationError: .otherRestoreError)
                await showSomethingWentWrongAlert()
            case .pastTransactionAuthenticationError:
                subscriptionErrorReporter.report(subscriptionActivationError: .otherRestoreError)
                await showSubscriptionNotFoundAlert()
            }
        }
    }

    // MARK: - UI interactions

    private func showSomethingWentWrongAlert() async {
        await uiHandler.show(alertType: .somethingWentWrong)
    }

    private func showSubscriptionNotFoundAlert() async {
        switch await uiHandler.show(alertType: .subscriptionNotFound) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }

    private func showSubscriptionInactiveAlert() async {
        switch await uiHandler.show(alertType: .subscriptionInactive) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }
}

@available(macOS 12.0, *)
struct DefaultSubscriptionAppStoreRestorerV2: SubscriptionAppStoreRestorer {
    private let subscriptionManager: SubscriptionManagerV2
    private let subscriptionErrorReporter: SubscriptionErrorReporter
    private let appStoreRestoreFlow: AppStoreRestoreFlowV2
    let uiHandler: SubscriptionUIHandling

    public init(subscriptionManager: SubscriptionManagerV2,
                subscriptionErrorReporter: SubscriptionErrorReporter = DefaultSubscriptionErrorReporter(),
                appStoreRestoreFlow: AppStoreRestoreFlowV2,
                uiHandler: SubscriptionUIHandling) {
        self.subscriptionManager = subscriptionManager
        self.subscriptionErrorReporter = subscriptionErrorReporter
        self.appStoreRestoreFlow = appStoreRestoreFlow
        self.uiHandler = uiHandler
    }

    func restoreAppStoreSubscription() async {
        await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)

        do {
            try await subscriptionManager.storePurchaseManager().syncAppleIDAccount()
            await continueRestore()
        } catch {
            await uiHandler.dismissProgressViewController()

            switch error as? StoreKitError {
            case .some(.userCancelled):
                break
            default:
                let alertResponse = await uiHandler.show(alertType: .appleIDSyncFailed, text: error.localizedDescription)
                if alertResponse == .alertFirstButtonReturn {
                    await uiHandler.presentProgressViewController(withTitle: UserText.restoringSubscriptionTitle)
                    await continueRestore()
                }
            }
        }
    }

    private func continueRestore() async {
        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
        await uiHandler.dismissProgressViewController()
        switch result {
        case .success:
            PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreSuccess, frequency: .legacyDailyAndCount)
        case .failure(let error):
            switch error {
            case .missingAccountOrTransactions:
                subscriptionErrorReporter.report(subscriptionActivationError: .restoreFailedDueToNoSubscription)
                await showSubscriptionNotFoundAlert()
            case .subscriptionExpired:
                subscriptionErrorReporter.report(subscriptionActivationError: .restoreFailedDueToExpiredSubscription)
                await showSubscriptionInactiveAlert()
            case .failedToObtainAccessToken, .failedToFetchAccountDetails, .failedToFetchSubscriptionDetails:
                subscriptionErrorReporter.report(subscriptionActivationError: .otherRestoreError)
                await showSomethingWentWrongAlert()
            case .pastTransactionAuthenticationError:
                subscriptionErrorReporter.report(subscriptionActivationError: .otherRestoreError)
                await showSubscriptionNotFoundAlert()
            }
        }
    }

    // MARK: - UI interactions

    private func showSomethingWentWrongAlert() async {
        await uiHandler.show(alertType: .somethingWentWrong)
    }

    private func showSubscriptionNotFoundAlert() async {
        switch await uiHandler.show(alertType: .subscriptionNotFound) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }

    private func showSubscriptionInactiveAlert() async {
        switch await uiHandler.show(alertType: .subscriptionInactive) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }
}
