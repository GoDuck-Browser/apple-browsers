//
//  AppDependencyProvider.swift
//  DuckDuckGo
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
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
import Core
import BrowserServicesKit
import DDGSync
import Bookmarks
import Subscription
import Common
import NetworkProtection
import RemoteMessaging
import PageRefreshMonitor
import PixelKit
import PixelExperimentKit
import Networking

protocol DependencyProvider {

    var appSettings: AppSettings { get }
    var variantManager: VariantManager { get }
    var internalUserDecider: InternalUserDecider { get }
    var featureFlagger: FeatureFlagger { get }
    var storageCache: StorageCache { get }
    var downloadManager: DownloadManager { get }
    var autofillLoginSession: AutofillLoginSession { get }
    var autofillNeverPromptWebsitesManager: AutofillNeverPromptWebsitesManager { get }
    var configurationManager: ConfigurationManager { get }
    var configurationStore: ConfigurationStore { get }
    var pageRefreshMonitor: PageRefreshMonitor { get }
    var vpnFeatureVisibility: DefaultNetworkProtectionVisibility { get }
    var networkProtectionKeychainTokenStore: NetworkProtectionKeychainTokenStore { get }
    var networkProtectionTunnelController: NetworkProtectionTunnelController { get }
    var connectionObserver: ConnectionStatusObserver { get }
    var serverInfoObserver: ConnectionServerInfoObserver { get }
    var vpnSettings: VPNSettings { get }
    var persistentPixel: PersistentPixelFiring { get }

    // Subscription
    var isAuthV2Enabled: Bool { get }
    var subscriptionAuthV1toV2Bridge: any SubscriptionAuthV1toV2Bridge { get }
    var subscriptionManager: (any SubscriptionManager)? { get }
    var subscriptionManagerV2: (any SubscriptionManagerV2)? { get }
}

/// Provides dependencies for objects that are not directly instantiated
/// through `init` call (e.g. ViewControllers created from Storyboards).
final class AppDependencyProvider: DependencyProvider {

    static var shared: DependencyProvider = AppDependencyProvider()
    let appSettings: AppSettings = AppUserDefaults()
    let variantManager: VariantManager = DefaultVariantManager()
    let internalUserDecider: InternalUserDecider = ContentBlocking.shared.privacyConfigurationManager.internalUserDecider
    let featureFlagger: FeatureFlagger

    let storageCache = StorageCache()
    let downloadManager = DownloadManager()
    let autofillLoginSession = AutofillLoginSession()
    lazy var autofillNeverPromptWebsitesManager = AutofillNeverPromptWebsitesManager()

    let configurationManager: ConfigurationManager
    let configurationStore = ConfigurationStore()

    let pageRefreshMonitor = PageRefreshMonitor(onDidDetectRefreshPattern: PageRefreshMonitor.onDidDetectRefreshPattern)

    // Subscription
    let isAuthV2Enabled = false
    var subscriptionAuthV1toV2Bridge: any SubscriptionAuthV1toV2Bridge {
        if !isAuthV2Enabled {
            return subscriptionManager!
        } else {
            return subscriptionManagerV2!
        }
    }
    var subscriptionManager: (any SubscriptionManager)?
    var subscriptionManagerV2: (any SubscriptionManagerV2)?

    let vpnFeatureVisibility: DefaultNetworkProtectionVisibility
    let networkProtectionKeychainTokenStore: NetworkProtectionKeychainTokenStore
    let networkProtectionTunnelController: NetworkProtectionTunnelController

    let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)

    let connectionObserver: ConnectionStatusObserver = ConnectionStatusObserverThroughSession()
    let serverInfoObserver: ConnectionServerInfoObserver = ConnectionServerInfoObserverThroughSession()
    let vpnSettings = VPNSettings(defaults: .networkProtectionGroupDefaults)
    let persistentPixel: PersistentPixelFiring = PersistentPixel()

    private init() {
        let featureFlaggerOverrides = FeatureFlagLocalOverrides(keyValueStore: UserDefaults(suiteName: FeatureFlag.localOverrideStoreName)!,
                                                                actionHandler: FeatureFlagOverridesPublishingHandler<FeatureFlag>()
        )
        let experimentManager = ExperimentCohortsManager(store: ExperimentsDataStore(), fireCohortAssigned: PixelKit.fireExperimentEnrollmentPixel(subfeatureID:experiment:))
        featureFlagger = DefaultFeatureFlagger(internalUserDecider: internalUserDecider,
                                               privacyConfigManager: ContentBlocking.shared.privacyConfigurationManager,
                                               localOverrides: featureFlaggerOverrides,
                                               experimentManager: experimentManager,
                                               for: FeatureFlag.self)

        configurationManager = ConfigurationManager(store: configurationStore)

        // MARK: - Configure Subscription

        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
        var tokenHandler: any SubscriptionTokenHandling
        var accessTokenProvider: () -> String?
        var authenticationStateProvider: (any SubscriptionAuthenticationStateProvider)!

        if !isAuthV2Enabled {
            // MARK: Subscription V1
            vpnSettings.alignTo(subscriptionEnvironment: subscriptionEnvironment)

            let entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: subscriptionUserDefaults,
                                                                     key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                                     settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))
            let accessTokenStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))
            let subscriptionEndpointService = DefaultSubscriptionEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
            let authService = DefaultAuthEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
            let subscriptionFeatureMappingCache = DefaultSubscriptionFeatureMappingCache(subscriptionEndpointService: subscriptionEndpointService,
                                                                                         userDefaults: subscriptionUserDefaults)
            let accountManager = DefaultAccountManager(accessTokenStorage: accessTokenStorage,
                                                       entitlementsCache: entitlementsCache,
                                                       subscriptionEndpointService: subscriptionEndpointService,
                                                       authEndpointService: authService)

            let storePurchaseManager = DefaultStorePurchaseManager(subscriptionFeatureMappingCache: subscriptionFeatureMappingCache)

            let subscriptionManager = DefaultSubscriptionManager(storePurchaseManager: storePurchaseManager,
                                                                 accountManager: accountManager,
                                                                 subscriptionEndpointService: subscriptionEndpointService,
                                                                 authEndpointService: authService,
                                                                 subscriptionFeatureMappingCache: subscriptionFeatureMappingCache,
                                                                 subscriptionEnvironment: subscriptionEnvironment,
                                                                 isInternalUserEnabled: { ContentBlocking.shared.privacyConfigurationManager.internalUserDecider.isInternalUser })
            accountManager.delegate = subscriptionManager

            self.subscriptionManager = subscriptionManager

            accessTokenProvider = {
                return { accountManager.accessToken }
            }()
            tokenHandler = accountManager
            authenticationStateProvider = subscriptionManager
        } else {
            // MARK: Subscription V2
            vpnSettings.alignTo(subscriptionEnvironment: subscriptionEnvironment)

            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let urlSession = URLSession(configuration: configuration,
                                        delegate: SessionDelegate(),
                                        delegateQueue: nil)
            let apiService = DefaultAPIService(urlSession: urlSession)
            let authEnvironment: OAuthEnvironment = subscriptionEnvironment.serviceEnvironment == .production ? .production : .staging

            let authService = DefaultOAuthService(baseURL: authEnvironment.url, apiService: apiService)

            // keychain storage
            let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
            let tokenStorage = SubscriptionTokenKeychainStorageV2(keychainType: .dataProtection(.named(subscriptionAppGroup))) { keychainType, error in
                Pixel.fire(.privacyProKeychainAccessError, withAdditionalParameters: ["type": keychainType.rawValue, "error": error.errorDescription])
            }
            let legacyAccountStorage = SubscriptionTokenKeychainStorage(keychainType: .dataProtection(.named(subscriptionAppGroup)))

            let authClient = DefaultOAuthClient(tokensStorage: tokenStorage,
                                                legacyTokenStorage: legacyAccountStorage,
                                                authService: authService)

            apiService.authorizationRefresherCallback = { _ in
                guard let tokenContainer = tokenStorage.tokenContainer else {
                    throw OAuthClientError.internalError("Missing refresh token")
                }

                if tokenContainer.decodedAccessToken.isExpired() {
                    Logger.OAuth.debug("Refreshing tokens")
                    let tokens = try await authClient.getTokens(policy: .localForceRefresh)
                    return tokens.accessToken
                } else {
                    Logger.general.debug("Trying to refresh valid token, using the old one")
                    return tokenContainer.accessToken
                }
            }
            let subscriptionEndpointService = DefaultSubscriptionEndpointServiceV2(apiService: apiService,
                                                                                   baseURL: subscriptionEnvironment.serviceEnvironment.url)
            let storePurchaseManager = DefaultStorePurchaseManagerV2(subscriptionFeatureMappingCache: subscriptionEndpointService)
            let pixelHandler: SubscriptionManagerV2.PixelHandler = { type in
                switch type {
                case .deadToken:
                    Pixel.fire(pixel: .privacyProDeadTokenDetected)
                case .subscriptionIsActive:
                    DailyPixel.fire(pixel: .privacyProSubscriptionActive)
                case .v1MigrationFailed:
                    Pixel.fire(pixel: .authV1MigrationFailed)
                case .v1MigrationSuccessful:
                    Pixel.fire(pixel: .authV1MigrationSucceeded)
                }
            }
            let subscriptionManager = DefaultSubscriptionManagerV2(storePurchaseManager: storePurchaseManager,
                                                                   oAuthClient: authClient,
                                                                   subscriptionEndpointService: subscriptionEndpointService,
                                                                   subscriptionEnvironment: subscriptionEnvironment,
                                                                   pixelHandler: pixelHandler,
                                                                   isInternalUserEnabled: {
                ContentBlocking.shared.privacyConfigurationManager.internalUserDecider.isInternalUser
            })

            let restoreFlow = DefaultAppStoreRestoreFlowV2(subscriptionManager: subscriptionManager, storePurchaseManager: storePurchaseManager)
            subscriptionManager.tokenRecoveryHandler = {
                try await DeadTokenRecoverer.attemptRecoveryFromPastPurchase(subscriptionManager: subscriptionManager, restoreFlow: restoreFlow)
            }

            self.subscriptionManagerV2 = subscriptionManager

            accessTokenProvider = {
                var token: String?
                // extremely ugly hack, will be removed as soon auth v1 is removed
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    token = try? await subscriptionManager.getTokenContainer(policy: .localValid).accessToken
                    semaphore.signal()
                }
                semaphore.wait()
                return { token }
            }()
            tokenHandler = subscriptionManager
            authenticationStateProvider = subscriptionManager
        }
        vpnFeatureVisibility = DefaultNetworkProtectionVisibility(authenticationStateProvider: authenticationStateProvider)
        networkProtectionKeychainTokenStore = NetworkProtectionKeychainTokenStore(accessTokenProvider: accessTokenProvider)
        networkProtectionTunnelController = NetworkProtectionTunnelController(tokenHandler: tokenHandler,
                                                                              featureFlagger: featureFlagger,
                                                                              persistentPixel: persistentPixel,
                                                                              settings: vpnSettings)

    }

}
