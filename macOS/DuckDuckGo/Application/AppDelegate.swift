//
//  AppDelegate.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Bookmarks
import BrowserServicesKit
import Cocoa
import Combine
import Common
import Configuration
import CoreData
import Crashes
import DDGSync
import FeatureFlags
import History
import HistoryView
import MetricKit
import Networking
import NewTabPage
import Persistence
import PixelKit
import PixelExperimentKit
import ServiceManagement
import SyncDataProviders
import UserNotifications
import Lottie
import NetworkProtection
import PrivacyStats
import Subscription
import NetworkProtectionIPC
import DataBrokerProtection_macOS
import DataBrokerProtectionCore
import RemoteMessaging
import os.log
import Freemium
import VPNAppState
import AIChat

final class AppDelegate: NSObject, NSApplicationDelegate {

#if DEBUG
    let disableCVDisplayLinkLogs: Void = {
        // Disable CVDisplayLink logs
        CFPreferencesSetValue("cv_note" as CFString,
                              0 as CFPropertyList,
                              "com.apple.corevideo" as CFString,
                              kCFPreferencesCurrentUser,
                              kCFPreferencesAnyHost)
        CFPreferencesSynchronize("com.apple.corevideo" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }()
#endif

    let urlEventHandler = URLEventHandler()

#if CI
    private let keyStore = (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
#else
    private let keyStore = EncryptionKeyStore()
#endif

    let fileStore: FileStore

#if APPSTORE
    private let crashCollection = CrashCollection(crashReportSender: CrashReportSender(platform: .macOSAppStore,
                                                                                       pixelEvents: CrashReportSender.pixelEvents))
#else
    private let crashReporter = CrashReporter()
#endif

    let keyValueStore: ThrowingKeyValueStoring

    let faviconManager: FaviconManager
    let pinnedTabsManager = PinnedTabsManager()
    let pinnedTabsManagerProvider: PinnedTabsManagerProviding!
    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    let internalUserDecider: InternalUserDecider
    private var isInternalUserSharingCancellable: AnyCancellable?
    let featureFlagger: FeatureFlagger
    let contentScopeExperimentsManager: ContentScopeExperimentsManaging
    let featureFlagOverridesPublishingHandler = FeatureFlagOverridesPublishingHandler<FeatureFlag>()
    private var appIconChanger: AppIconChanger!
    private var autoClearHandler: AutoClearHandler!
    private(set) var autofillPixelReporter: AutofillPixelReporter?

    private(set) var syncDataProviders: SyncDataProviders!
    private(set) var syncService: DDGSyncing?
    private var isSyncInProgressCancellable: AnyCancellable?
    private var syncFeatureFlagsCancellable: AnyCancellable?
    private var screenLockedCancellable: AnyCancellable?
    private var emailCancellables = Set<AnyCancellable>()
    let bookmarksManager = LocalBookmarkManager.shared
    var privacyDashboardWindow: NSWindow?

    private var updateProgressCancellable: AnyCancellable?

    private(set) lazy var newTabPageCoordinator: NewTabPageCoordinator = NewTabPageCoordinator(
        appearancePreferences: .shared,
        customizationModel: newTabPageCustomizationModel,
        activeRemoteMessageModel: activeRemoteMessageModel,
        historyCoordinator: HistoryCoordinator.shared,
        privacyStats: privacyStats,
        freemiumDBPPromotionViewCoordinator: freemiumDBPPromotionViewCoordinator
    )

    private(set) lazy var aiChatTabOpener: AIChatTabOpening = AIChatTabOpener(
        promptHandler: AIChatPromptHandler.shared,
        addressBarQueryExtractor: AIChatAddressBarPromptExtractor()
    )

    let privacyStats: PrivacyStatsCollecting
    let activeRemoteMessageModel: ActiveRemoteMessageModel
    let newTabPageCustomizationModel: NewTabPageCustomizationModel
    let remoteMessagingClient: RemoteMessagingClient!
    let onboardingContextualDialogsManager: ContextualOnboardingDialogTypeProviding & ContextualOnboardingStateUpdater
    let defaultBrowserAndDockPromptPresenter: DefaultBrowserAndDockPromptPresenter
    let visualStyleManager: VisualStyleManagerProviding

    let isAuthV2Enabled: Bool
    var subscriptionAuthV1toV2Bridge: any SubscriptionAuthV1toV2Bridge
    let subscriptionManagerV1: (any SubscriptionManager)?
    let subscriptionManagerV2: (any SubscriptionManagerV2)?

    public let subscriptionUIHandler: SubscriptionUIHandling
    private let subscriptionCookieManager: any SubscriptionCookieManaging
    private var subscriptionCookieManagerFeatureFlagCancellable: AnyCancellable?

    // MARK: - Freemium DBP
    public let freemiumDBPFeature: FreemiumDBPFeature
    public let freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator
    private var freemiumDBPScanResultPolling: FreemiumDBPScanResultPolling?

    var configurationStore = ConfigurationStore()
    var configurationManager: ConfigurationManager

    // MARK: - VPN

    public let vpnSettings = VPNSettings(defaults: .netP)

    private lazy var vpnAppEventsHandler = VPNAppEventsHandler(
        featureGatekeeper: DefaultVPNFeatureGatekeeper(subscriptionManager: subscriptionAuthV1toV2Bridge),
        featureFlagOverridesPublishingHandler: featureFlagOverridesPublishingHandler,
        defaults: .netP)
    private var networkProtectionSubscriptionEventHandler: NetworkProtectionSubscriptionEventHandler?

    private var vpnXPCClient: VPNControllerXPCClient {
        VPNControllerXPCClient.shared
    }

    // MARK: - DBP

    private lazy var dataBrokerProtectionSubscriptionEventHandler: DataBrokerProtectionSubscriptionEventHandler = {
        let authManager = DataBrokerAuthenticationManagerBuilder.buildAuthenticationManager(subscriptionManager: subscriptionAuthV1toV2Bridge)
        return DataBrokerProtectionSubscriptionEventHandler(featureDisabler: DataBrokerProtectionFeatureDisabler(),
                                                            authenticationManager: authManager,
                                                            pixelHandler: DataBrokerProtectionMacOSPixelsHandler())
    }()

    private var didFinishLaunching = false

#if SPARKLE
    var updateController: UpdateController!
    var dockCustomization: DockCustomization?
#endif

    @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: Date.monthAgo)
    static var firstLaunchDate: Date

    @UserDefaultsWrapper
    private var didCrashDuringCrashHandlersSetUp: Bool

    static var isNewUser: Bool {
        return firstLaunchDate >= Date.weekAgo
    }

    static var twoDaysPassedSinceFirstLaunch: Bool {
        return firstLaunchDate.daysSinceNow() >= 2
    }

    // swiftlint:disable cyclomatic_complexity
    @MainActor
    override init() {
        // will not add crash handlers and will fire pixel on applicationDidFinishLaunching if didCrashDuringCrashHandlersSetUp == true
        let didCrashDuringCrashHandlersSetUp = UserDefaultsWrapper(key: .didCrashDuringCrashHandlersSetUp, defaultValue: false)
        _didCrashDuringCrashHandlersSetUp = didCrashDuringCrashHandlersSetUp
        if case .normal = AppVersion.runType,
           !didCrashDuringCrashHandlersSetUp.wrappedValue {

            didCrashDuringCrashHandlersSetUp.wrappedValue = true
            CrashLogMessageExtractor.setUp(swapCxaThrow: false)
            didCrashDuringCrashHandlersSetUp.wrappedValue = false
        }

        do {
            keyValueStore = try KeyValueFileStore(location: URL.sandboxApplicationSupportURL, name: "AppKeyValueStore")
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.keyValueFileStoreInitError, error: error))
            Thread.sleep(forTimeInterval: 1)
            fatalError("Could not prepare key value store: \(error.localizedDescription)")
        }

        do {
            let encryptionKey = AppVersion.runType.requiresEnvironment ? try keyStore.readKey() : nil
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            Logger.general.error("App Encryption Key could not be read: \(error.localizedDescription)")
            fileStore = EncryptedFileStore()
        }

        let internalUserDeciderStore = InternalUserDeciderStore(fileStore: fileStore)
        internalUserDecider = DefaultInternalUserDecider(store: internalUserDeciderStore)

        if AppVersion.runType.requiresEnvironment {
            Self.configurePixelKit()

            Database.shared.loadStore { _, error in
                guard let error = error else { return }

                switch error {
                case CoreDataDatabase.Error.containerLocationCouldNotBePrepared(let underlyingError):
                    PixelKit.fire(DebugEvent(GeneralPixel.dbContainerInitializationError(error: underlyingError)))
                default:
                    PixelKit.fire(DebugEvent(GeneralPixel.dbInitializationError(error: error)))
                }

                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }

            do {
                let formFactorFavMigration = BookmarkFormFactorFavoritesMigration()
                let favoritesOrder = try formFactorFavMigration.getFavoritesOrderFromPreV4Model(dbContainerLocation: BookmarkDatabase.defaultDBLocation,
                                                                                                dbFileURL: BookmarkDatabase.defaultDBFileURL)
                BookmarkDatabase.shared.preFormFactorSpecificFavoritesFolderOrder = favoritesOrder
            } catch {
                PixelKit.fire(DebugEvent(GeneralPixel.bookmarksCouldNotLoadDatabase(error: error)))
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not create Bookmarks database stack: \(error.localizedDescription)")
            }

            BookmarkDatabase.shared.db.loadStore { context, error in
                guard let context = context else {
                    PixelKit.fire(DebugEvent(GeneralPixel.bookmarksCouldNotLoadDatabase(error: error)))
                    Thread.sleep(forTimeInterval: 1)
                    fatalError("Could not create Bookmarks database stack: \(error?.localizedDescription ?? "err")")
                }

                let legacyDB = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType)
                legacyDB.performAndWait {
                    LegacyBookmarksStoreMigration.setupAndMigrate(from: legacyDB,
                                                                  to: context)
                }
            }
        }

#if DEBUG
        AppPrivacyFeatures.shared = AppVersion.runType.requiresEnvironment
        // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
        ? AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider, configurationStore: configurationStore), database: Database.shared)
        : AppPrivacyFeatures(contentBlocking: ContentBlockingMock(), httpsUpgradeStore: HTTPSUpgradeStoreMock())
#else
        AppPrivacyFeatures.shared = AppPrivacyFeatures(contentBlocking: AppContentBlocking(internalUserDecider: internalUserDecider, configurationStore: configurationStore), database: Database.shared)
#endif

        pinnedTabsManagerProvider = PinnedTabsManagerProvider()

        configurationManager = ConfigurationManager(store: configurationStore)

        let featureFlagger = DefaultFeatureFlagger(
            internalUserDecider: internalUserDecider,
            privacyConfigManager: AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager,
            localOverrides: FeatureFlagLocalOverrides(
                keyValueStore: UserDefaults.appConfiguration,
                actionHandler: featureFlagOverridesPublishingHandler
            ),
            experimentManager: ExperimentCohortsManager(store: ExperimentsDataStore(), fireCohortAssigned: PixelKit.fireExperimentEnrollmentPixel(subfeatureID:experiment:)),
            for: FeatureFlag.self
        )
        self.featureFlagger = featureFlagger
        self.contentScopeExperimentsManager = featureFlagger

        let coordinator =  DefaultBrowserAndDockPromptCoordinator(featureFlagger: featureFlagger)
        defaultBrowserAndDockPromptPresenter = DefaultBrowserAndDockPromptPresenter(coordinator: coordinator, featureFlagger: featureFlagger)

        visualStyleManager = VisualStyleManager(featureFlagger: featureFlagger)
        newTabPageCustomizationModel = NewTabPageCustomizationModel(visualStyleManager: visualStyleManager)

        onboardingContextualDialogsManager = ContextualDialogsManager()

        // MARK: - Subscription configuration

        subscriptionUIHandler = SubscriptionUIHandler(windowControllersManagerProvider: {
            return WindowControllersManager.shared
        })

        self.isAuthV2Enabled = featureFlagger.isFeatureOn(.privacyProAuthV2)
        if !isAuthV2Enabled {
            // MARK: V1
            Logger.general.log("Using Auth V1")
            let subscriptionManager = DefaultSubscriptionManager(featureFlagger: featureFlagger)
            subscriptionCookieManager = SubscriptionCookieManager(tokenProvider: subscriptionManager, currentCookieStore: {
                WKHTTPCookieStoreWrapper(store: WKWebsiteDataStore.default().httpCookieStore)
            }, eventMapping: SubscriptionCookieManageEventPixelMapping())
            subscriptionManagerV1 = subscriptionManager
            subscriptionManagerV2 = nil
            subscriptionAuthV1toV2Bridge = subscriptionManager
        } else {
            // MARK: V2
            Logger.general.log("Using Auth V2")
            let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
            let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
            let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
            let subscriptionManager = DefaultSubscriptionManagerV2(keychainType: KeychainType.dataProtection(.named(subscriptionAppGroup)),
                                                                   environment: subscriptionEnvironment,
                                                                   featureFlagger: featureFlagger,
                                                                   userDefaults: subscriptionUserDefaults,
                                                                   canPerformAuthMigration: true,
                                                                   pixelHandlingSource: .mainApp)

            // Expired refresh token recovery
            if #available(iOS 15.0, macOS 12.0, *) {
                let restoreFlow = DefaultAppStoreRestoreFlowV2(subscriptionManager: subscriptionManager, storePurchaseManager: subscriptionManager.storePurchaseManager())
                subscriptionManager.tokenRecoveryHandler = {
                    do {
                        try await DeadTokenRecoverer.attemptRecoveryFromPastPurchase(subscriptionManager: subscriptionManager, restoreFlow: restoreFlow)
                        PixelKit.fire(PrivacyProPixel.privacyProInvalidRefreshTokenRecovered, frequency: .dailyAndCount)
                    } catch {
                        PixelKit.fire(PrivacyProPixel.privacyProInvalidRefreshTokenSignedOut, frequency: .dailyAndCount)
                    }
                }
            } else {
                subscriptionManager.tokenRecoveryHandler = {
                    try await DeadTokenRecoverer.reportDeadRefreshToken()
                    PixelKit.fire(PrivacyProPixel.privacyProInvalidRefreshTokenSignedOut, frequency: .dailyAndCount)
                }
            }

            subscriptionCookieManager = SubscriptionCookieManagerV2(subscriptionManager: subscriptionManager, currentCookieStore: {
                WKHTTPCookieStoreWrapper(store: WKWebsiteDataStore.default().httpCookieStore)
            }, eventMapping: SubscriptionCookieManageEventPixelMapping())
            subscriptionManagerV2 = subscriptionManager
            subscriptionManagerV1 = nil
            subscriptionAuthV1toV2Bridge = subscriptionManager
        }
        VPNAppState(defaults: .netP).isAuthV2Enabled = isAuthV2Enabled

        if AppVersion.runType.requiresEnvironment {
            remoteMessagingClient = RemoteMessagingClient(
                database: RemoteMessagingDatabase().db,
                bookmarksDatabase: BookmarkDatabase.shared.db,
                appearancePreferences: .shared,
                pinnedTabsManagerProvider: pinnedTabsManagerProvider,
                internalUserDecider: internalUserDecider,
                configurationStore: configurationStore,
                remoteMessagingAvailabilityProvider: PrivacyConfigurationRemoteMessagingAvailabilityProvider(
                    privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager
                ),
                subscriptionManager: subscriptionAuthV1toV2Bridge
            )
            activeRemoteMessageModel = ActiveRemoteMessageModel(remoteMessagingClient: remoteMessagingClient, openURLHandler: { url in
                WindowControllersManager.shared.showTab(with: .contentFromURL(url, source: .appOpenUrl))
            })
        } else {
            // As long as remoteMessagingClient is private to App Delegate and activeRemoteMessageModel
            // is used only by HomePage RootView as environment object,
            // it's safe to not initialize the client for unit tests to avoid side effects.
            remoteMessagingClient = nil
            activeRemoteMessageModel = ActiveRemoteMessageModel(
                remoteMessagingStore: nil,
                remoteMessagingAvailabilityProvider: nil,
                openURLHandler: { _ in }
            )
        }

        // Update VPN environment and match the Subscription environment
        vpnSettings.alignTo(subscriptionEnvironment: subscriptionAuthV1toV2Bridge.currentEnvironment)

        // Update DBP environment and match the Subscription environment
        let dbpSettings = DataBrokerProtectionSettings(defaults: .dbp)
        dbpSettings.alignTo(subscriptionEnvironment: subscriptionAuthV1toV2Bridge.currentEnvironment)
        dbpSettings.isAuthV2Enabled = isAuthV2Enabled

        // Also update the stored run type so the login item knows if tests are running
        dbpSettings.updateStoredRunType()

        // Freemium DBP
        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)

        let experimentManager = FreemiumDBPPixelExperimentManager(subscriptionManager: subscriptionAuthV1toV2Bridge)
        experimentManager.assignUserToCohort()

        freemiumDBPFeature = DefaultFreemiumDBPFeature(privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager,
                                                       experimentManager: experimentManager,
                                                       subscriptionManager: subscriptionAuthV1toV2Bridge,
                                                       freemiumDBPUserStateManager: freemiumDBPUserStateManager)
        freemiumDBPPromotionViewCoordinator = FreemiumDBPPromotionViewCoordinator(freemiumDBPUserStateManager: freemiumDBPUserStateManager,
                                                                                  freemiumDBPFeature: freemiumDBPFeature)

#if DEBUG
        if AppVersion.runType.requiresEnvironment {
            privacyStats = PrivacyStats(databaseProvider: PrivacyStatsDatabase(), errorEvents: PrivacyStatsErrorHandler())
        } else {
            privacyStats = MockPrivacyStats()
        }
#else
        privacyStats = PrivacyStats(databaseProvider: PrivacyStatsDatabase())
#endif
        PixelKit.configureExperimentKit(featureFlagger: featureFlagger, eventTracker: ExperimentEventTracker(store: UserDefaults.appConfiguration))

#if DEBUG
        faviconManager = FaviconManager(cacheType: AppVersion.runType.requiresEnvironment ? .standard : .inMemory)
#else
        faviconManager = FaviconManager(cacheType: .standard)
#endif

#if !APPSTORE && WEB_EXTENSIONS_ENABLED
        if #available(macOS 15.4, *) {
            Task { @MainActor in
                await WebExtensionManager.shared.loadInstalledExtensions()
            }
        }
#endif
    }
    // swiftlint:enable cyclomatic_complexity

    func applicationWillFinishLaunching(_ notification: Notification) {
        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        Configuration.setURLProvider(AppConfigurationURLProvider())

        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

#if SPARKLE
        if AppVersion.runType != .uiTests {
            updateController = UpdateController(internalUserDecider: internalUserDecider)
            stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
        }
#endif

        appIconChanger = AppIconChanger(internalUserDecider: internalUserDecider)

        // Configure Event handlers
        let tunnelController = NetworkProtectionIPCTunnelController(ipcClient: vpnXPCClient)
        let vpnUninstaller = VPNUninstaller(ipcClient: vpnXPCClient)

        networkProtectionSubscriptionEventHandler = NetworkProtectionSubscriptionEventHandler(subscriptionManager: subscriptionAuthV1toV2Bridge,
                                                                                              tunnelController: tunnelController,
                                                                                              vpnUninstaller: vpnUninstaller)

        // Freemium DBP
        freemiumDBPFeature.subscribeToDependencyUpdates()

        // ignore popovers shown from a view not in view hierarchy
        // https://app.asana.com/0/1201037661562251/1206407295280737/f
        _ = NSPopover.swizzleShowRelativeToRectOnce
        // disable macOS system-wide window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false
        // Fix SwifUI context menus and its owner View leaking
        SwiftUIContextMenuRetainCycleFix.setUp()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppVersion.runType.requiresEnvironment else { return }
        defer {
            didFinishLaunching = true
        }

        Task {
            await subscriptionManagerV1?.loadInitialData()
            await subscriptionManagerV2?.loadInitialData()

            vpnAppEventsHandler.applicationDidFinishLaunching()
        }

        HistoryCoordinator.shared.loadHistory {
            HistoryCoordinator.shared.migrateModelV5toV6IfNeeded()
        }

        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        bookmarksManager.loadBookmarks()

        // Force use of .mainThread to prevent high WindowServer Usage
        // Pending Fix with newer Lottie versions
        // https://app.asana.com/0/1177771139624306/1207024603216659/f
        LottieConfiguration.shared.renderingEngine = .mainThread

        configurationManager.start()
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        if LocalStatisticsStore().atb == nil {
            AppDelegate.firstLaunchDate = Date()
        }
        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        #if SPARKLE
        dockCustomization = DockCustomizer()
        #endif

        let statisticsLoader = AppVersion.runType.requiresEnvironment ? StatisticsLoader.shared : nil
        statisticsLoader?.load()

        startupSync()

        let privacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager

        // Enable subscriptionCookieManager if feature flag is present
        if privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(PrivacyProSubfeature.setAccessTokenCookieForSubscriptionDomains) {
            subscriptionCookieManager.enableSettingSubscriptionCookie()
        }

        // Keep track of feature flag changes
        subscriptionCookieManagerFeatureFlagCancellable = privacyConfigurationManager.updatesPublisher
            .sink { [weak self, weak privacyConfigurationManager] in
                guard let self, let privacyConfigurationManager else { return }

                let isEnabled = privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(PrivacyProSubfeature.setAccessTokenCookieForSubscriptionDomains)

                Task { @MainActor [weak self] in
                    if isEnabled {
                        self?.subscriptionCookieManager.enableSettingSubscriptionCookie()
                    } else {
                        await self?.subscriptionCookieManager.disableSettingSubscriptionCookie()
                    }
                }
            }

        if [.normal, .uiTests].contains(AppVersion.runType) {
            stateRestorationManager.applicationDidFinishLaunching()
        }

        BWManager.shared.initCommunication()

        if WindowsManager.windows.first(where: { $0 is MainWindow }) == nil,
           case .normal = AppVersion.runType {
            WindowsManager.openNewWindow(lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

#if APPSTORE
        crashCollection.startAttachingCrashLogMessages { pixelParameters, payloads, completion in
            pixelParameters.forEach { parameters in
                PixelKit.fire(GeneralPixel.crash, withAdditionalParameters: parameters, includeAppVersionParameter: false)
                PixelKit.fire(GeneralPixel.crashDaily, frequency: .legacyDaily)
            }

            guard let lastPayload = payloads.last else {
                return
            }
            DispatchQueue.main.async {
                CrashReportPromptPresenter().showPrompt(for: CrashDataPayload(data: lastPayload), userDidAllowToReport: completion)
            }
        }
#else
        crashReporter.checkForNewReports()
#endif

        urlEventHandler.applicationDidFinishLaunching()

        subscribeToEmailProtectionStatusNotifications()
        subscribeToDataImportCompleteNotification()
        subscribeToInternalUserChanges()
        subscribeToUpdateControllerChanges()

        fireFailedCompilationsPixelIfNeeded()

        UserDefaultsWrapper<Any>.clearRemovedKeys()

        networkProtectionSubscriptionEventHandler?.registerForSubscriptionAccountManagerEvents()

        UNUserNotificationCenter.current().delegate = self

        dataBrokerProtectionSubscriptionEventHandler.registerForSubscriptionAccountManagerEvents()

        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)
        let pirGatekeeper = DefaultDataBrokerProtectionFeatureGatekeeper(subscriptionManager: subscriptionAuthV1toV2Bridge,
                                                                         freemiumDBPUserStateManager: freemiumDBPUserStateManager)

        DataBrokerProtectionAppEvents(featureGatekeeper: pirGatekeeper).applicationDidFinishLaunching()

        TipKitAppEventHandler(featureFlagger: featureFlagger).appDidFinishLaunching()

        setUpAutoClearHandler()

        setUpAutofillPixelReporter()

        remoteMessagingClient?.startRefreshingRemoteMessages()

        // This messaging system has been replaced by RMF, but we need to clean up the message manifest for any users who had it stored.
        let deprecatedRemoteMessagingStorage = DefaultSurveyRemoteMessagingStorage.surveys()
        deprecatedRemoteMessagingStorage.removeStoredMessagesIfNecessary()

        if didCrashDuringCrashHandlersSetUp {
            PixelKit.fire(GeneralPixel.crashOnCrashHandlersSetUp)
            didCrashDuringCrashHandlersSetUp = false
        }

        freemiumDBPScanResultPolling = DefaultFreemiumDBPScanResultPolling(dataManager: DataBrokerProtectionManager.shared.dataManager, freemiumDBPUserStateManager: freemiumDBPUserStateManager)
        freemiumDBPScanResultPolling?.startPollingOrObserving()
    }

    private func fireFailedCompilationsPixelIfNeeded() {
        let store = FailedCompilationsStore()
        if store.hasAnyFailures {
            PixelKit.fire(DebugEvent(GeneralPixel.compilationFailed),
                          frequency: .daily,
                          withAdditionalParameters: store.summary,
                          includeAppVersionParameter: true) { didFire, _ in
                if !didFire {
                    store.cleanup()
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard didFinishLaunching else { return }

        fireAppLaunchPixel()

        initializeSync()

        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)
        let pirGatekeeper = DefaultDataBrokerProtectionFeatureGatekeeper(subscriptionManager: subscriptionAuthV1toV2Bridge,
                                                                         freemiumDBPUserStateManager: freemiumDBPUserStateManager)

        DataBrokerProtectionAppEvents(featureGatekeeper: pirGatekeeper).applicationDidBecomeActive()

        subscriptionManagerV1?.refreshCachedSubscriptionAndEntitlements { isSubscriptionActive in
            if isSubscriptionActive {
                PixelKit.fire(PrivacyProPixel.privacyProSubscriptionActive, frequency: .daily)
            }
        }

        Task { @MainActor in
            await subscriptionCookieManager.refreshSubscriptionCookie()
        }
    }

    private func fireAppLaunchPixel() {
#if SPARKLE
        PixelKit.fire(NonStandardEvent(GeneralPixel.launch(isDefault: DefaultBrowserPreferences().isDefault, isAddedToDock: DockCustomizer().isAddedToDock)), frequency: .daily)
#else
        PixelKit.fire(NonStandardEvent(GeneralPixel.launch(isDefault: DefaultBrowserPreferences().isDefault, isAddedToDock: nil)), frequency: .daily)
#endif
    }

    private func initializeSync() {
        guard let syncService else { return }
        syncService.initializeIfNeeded()
        syncService.scheduler.notifyAppLifecycleEvent()
        SyncDiagnosisHelper(syncService: syncService).diagnoseAccountStatus()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !FileDownloadManager.shared.downloads.isEmpty {
            // if there‘re downloads without location chosen yet (save dialog should display) - ignore them
            let activeDownloads = Set(FileDownloadManager.shared.downloads.filter { $0.state.isDownloading })
            if !activeDownloads.isEmpty {
                let alert = NSAlert.activeDownloadsTerminationAlert(for: FileDownloadManager.shared.downloads)
                let downloadsFinishedCancellable = FileDownloadManager.observeDownloadsFinished(activeDownloads) {
                    // close alert and burn the window when all downloads finished
                    NSApp.stopModal(withCode: .OK)
                }
                let response = alert.runModal()
                downloadsFinishedCancellable.cancel()
                if response == .cancel {
                    return .terminateCancel
                }
            }
            FileDownloadManager.shared.cancelAll(waitUntilDone: true)
            DownloadListCoordinator.shared.sync()
        }
        stateRestorationManager?.applicationWillTerminate()

        // Handling of "Burn on quit"
        if let terminationReply = autoClearHandler.handleAppTermination() {
            return terminationReply
        }

        tearDownPrivacyStats()

        return .terminateNow
    }

    func tearDownPrivacyStats() {
        let condition = RunLoop.ResumeCondition()
        Task {
            await privacyStats.handleAppTermination()
            condition.resolve()
        }
        RunLoop.current.run(until: condition)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if WindowControllersManager.shared.mainWindowControllers.isEmpty,
           case .normal = AppVersion.runType {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return ApplicationDockMenu(internalUserDecider: internalUserDecider)
    }

    func application(_ sender: NSApplication, openFiles files: [String]) {
        urlEventHandler.handleFiles(files)
    }

    // MARK: - PixelKit

    static func configurePixelKit() {
#if DEBUG || REVIEW
            Self.setUpPixelKit(dryRun: true)
#else
            Self.setUpPixelKit(dryRun: false)
#endif
    }

    private static func setUpPixelKit(dryRun: Bool) {
#if APPSTORE
        let source = "browser-appstore"
#else
        let source = "browser-dmg"
#endif

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let trimmedOSVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
        let userAgent = UserAgent.duckDuckGoUserAgent(systemVersion: trimmedOSVersion)

        PixelKit.setUp(dryRun: dryRun,
                       appVersion: AppVersion.shared.versionNumber,
                       source: source,
                       defaultHeaders: [:],
                       defaults: .netP) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping PixelKit.CompletionBlock) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(userAgent: userAgent, additionalHeaders: headers)
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error == nil, error)
            }
        }
    }

    // MARK: - Theme

    private func applyPreferredTheme() {
        let appearancePreferences = AppearancePreferences()
        appearancePreferences.updateUserInterfaceStyle()
    }

    // MARK: - Sync

    private func startupSync() {
#if DEBUG
        let defaultEnvironment = ServerEnvironment.development
#else
        let defaultEnvironment = ServerEnvironment.production
#endif

#if DEBUG || REVIEW
        let environment = ServerEnvironment(
            UserDefaultsWrapper(key: .syncEnvironment, defaultValue: defaultEnvironment.description).wrappedValue
        ) ?? defaultEnvironment
#else
        let environment = defaultEnvironment
#endif
        let syncErrorHandler = SyncErrorHandler()
        let syncDataProviders = SyncDataProviders(bookmarksDatabase: BookmarkDatabase.shared.db, syncErrorHandler: syncErrorHandler)
        let syncService = DDGSync(
            dataProvidersSource: syncDataProviders,
            errorEvents: SyncErrorHandler(),
            privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager,
            keyValueStore: keyValueStore,
            environment: environment
        )
        syncService.initializeIfNeeded()
        syncDataProviders.setUpDatabaseCleaners(syncService: syncService)

        // This is also called in applicationDidBecomeActive, but we're also calling it here, since
        // syncService can be nil when applicationDidBecomeActive is called during startup, if a modal
        // alert is shown before it's instantiated.  In any case it should be safe to call this here,
        // since the scheduler debounces calls to notifyAppLifecycleEvent().
        //
        syncService.scheduler.notifyAppLifecycleEvent()

        self.syncDataProviders = syncDataProviders
        self.syncService = syncService

        isSyncInProgressCancellable = syncService.isSyncInProgressPublisher
            .filter { $0 }
            .asVoid()
            .sink { [weak syncService] in
                PixelKit.fire(GeneralPixel.syncDaily, frequency: .legacyDaily)
                syncService?.syncDailyStats.sendStatsIfNeeded(handler: { params in
                    PixelKit.fire(GeneralPixel.syncSuccessRateDaily, withAdditionalParameters: params)
                })
            }

        subscribeSyncQueueToScreenLockedNotifications()
        subscribeToSyncFeatureFlags(syncService)
    }

    @UserDefaultsWrapper(key: .syncDidShowSyncPausedByFeatureFlagAlert, defaultValue: false)
    private var syncDidShowSyncPausedByFeatureFlagAlert: Bool

    private func subscribeToSyncFeatureFlags(_ syncService: DDGSync) {
        syncFeatureFlagsCancellable = syncService.featureFlagsPublisher
            .dropFirst()
            .map { $0.contains(.dataSyncing) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak syncService] isDataSyncingAvailable in
                if isDataSyncingAvailable {
                    self?.syncDidShowSyncPausedByFeatureFlagAlert = false
                } else if syncService?.authState == .active, self?.syncDidShowSyncPausedByFeatureFlagAlert == false {
                    let isSyncUIVisible = syncService?.featureFlags.contains(.userInterface) == true
                    let alert = NSAlert.dataSyncingDisabledByFeatureFlag(showLearnMore: isSyncUIVisible)
                    let response = alert.runModal()
                    self?.syncDidShowSyncPausedByFeatureFlagAlert = true

                    switch response {
                    case .alertSecondButtonReturn:
                        alert.window.sheetParent?.endSheet(alert.window)
                        DispatchQueue.main.async {
                            WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .sync)
                        }
                    default:
                        break
                    }
                }
            }
    }

    private func subscribeSyncQueueToScreenLockedNotifications() {
        let screenIsLockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsLocked"))
            .map { _ in true }
        let screenIsUnlockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsUnlocked"))
            .map { _ in false }

        screenLockedCancellable = Publishers.Merge(screenIsLockedPublisher, screenIsUnlockedPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                guard let syncService = self?.syncService, syncService.authState != .inactive else {
                    return
                }
                if isLocked {
                    Logger.sync.debug("Screen is locked")
                    syncService.scheduler.cancelSyncAndSuspendSyncQueue()
                } else {
                    Logger.sync.debug("Screen is unlocked")
                    syncService.scheduler.resumeSyncQueue()
                }
            }
    }

    private func subscribeToEmailProtectionStatusNotifications() {
        NotificationCenter.default.publisher(for: .emailDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.emailDidSignInNotification(notification)
            }
            .store(in: &emailCancellables)

        NotificationCenter.default.publisher(for: .emailDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.emailDidSignOutNotification(notification)
            }
            .store(in: &emailCancellables)
    }

    private func subscribeToDataImportCompleteNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(dataImportCompleteNotification(_:)), name: .dataImportComplete, object: nil)
    }

    private func subscribeToInternalUserChanges() {
        UserDefaults.appConfiguration.isInternalUser = internalUserDecider.isInternalUser

        isInternalUserSharingCancellable = internalUserDecider.isInternalUserPublisher
            .assign(to: \.isInternalUser, onWeaklyHeld: UserDefaults.appConfiguration)
    }

    private func subscribeToUpdateControllerChanges() {
#if SPARKLE
        guard AppVersion.runType != .uiTests else { return }

        updateProgressCancellable = updateController.updateProgressPublisher
            .sink { [weak self] progress in
                self?.updateController.checkNewApplicationVersionIfNeeded(updateProgress: progress)
            }
#endif
    }

    private func emailDidSignInNotification(_ notification: Notification) {
        PixelKit.fire(NonStandardEvent(NonStandardPixel.emailEnabled))
        if AppDelegate.isNewUser {
            PixelKit.fire(GeneralPixel.emailEnabledInitial, frequency: .legacyInitial)
        }

        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    private func emailDidSignOutNotification(_ notification: Notification) {
        PixelKit.fire(NonStandardEvent(NonStandardPixel.emailDisabled))
        if let object = notification.object as? EmailManager, let emailManager = syncDataProviders.settingsAdapter.emailManager, object !== emailManager {
            syncService?.scheduler.notifyDataChanged()
        }
    }

    @objc private func dataImportCompleteNotification(_ notification: Notification) {
        if AppDelegate.isNewUser {
            PixelKit.fire(GeneralPixel.importDataInitial, frequency: .legacyInitial)
        }
    }

    @MainActor
    private func setUpAutoClearHandler() {
        let autoClearHandler = AutoClearHandler(preferences: .shared,
                                                fireViewModel: FireCoordinator.fireViewModel,
                                                stateRestorationManager: self.stateRestorationManager)
        self.autoClearHandler = autoClearHandler
        DispatchQueue.main.async {
            autoClearHandler.handleAppLaunch()
            autoClearHandler.onAutoClearCompleted = {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }
    }

    private func setUpAutofillPixelReporter() {
        autofillPixelReporter = AutofillPixelReporter(
            standardUserDefaults: .standard,
            appGroupUserDefaults: nil,
            autofillEnabled: AutofillPreferences().askToSaveUsernamesAndPasswords,
            eventMapping: EventMapping<AutofillPixelEvent> {event, _, params, _ in
                switch event {
                case .autofillActiveUser:
                    PixelKit.fire(GeneralPixel.autofillActiveUser)
                case .autofillEnabledUser:
                    PixelKit.fire(GeneralPixel.autofillEnabledUser)
                case .autofillOnboardedUser:
                    PixelKit.fire(GeneralPixel.autofillOnboardedUser)
                case .autofillToggledOn:
                    PixelKit.fire(GeneralPixel.autofillToggledOn, withAdditionalParameters: params)
                case .autofillToggledOff:
                    PixelKit.fire(GeneralPixel.autofillToggledOff, withAdditionalParameters: params)
                case .autofillLoginsStacked:
                    PixelKit.fire(GeneralPixel.autofillLoginsStacked, withAdditionalParameters: params)
                case .autofillCreditCardsStacked:
                    PixelKit.fire(GeneralPixel.autofillCreditCardsStacked, withAdditionalParameters: params)
                case .autofillIdentitiesStacked:
                    PixelKit.fire(GeneralPixel.autofillIdentitiesStacked, withAdditionalParameters: params)
                }
            },
            passwordManager: PasswordManagerCoordinator.shared,
            installDate: AppDelegate.firstLaunchDate)

        _ = NotificationCenter.default.addObserver(forName: .autofillUserSettingsDidChange,
                                                   object: nil,
                                                   queue: nil) { [weak self] _ in
            self?.autofillPixelReporter?.updateAutofillEnabledStatus(AutofillPreferences().askToSaveUsernamesAndPasswords)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.banner)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

}
