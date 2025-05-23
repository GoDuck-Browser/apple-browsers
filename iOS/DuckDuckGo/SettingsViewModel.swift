//
//  SettingsViewModel.swift
//  DuckDuckGo
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

import Core
import BrowserServicesKit
import Persistence
import SwiftUI
import Common
import Combine
import SyncUI_iOS
import DuckPlayer
import Crashes

import Subscription
import NetworkProtection
import AIChat

final class SettingsViewModel: ObservableObject {

    // Dependencies
    private(set) lazy var appSettings = AppDependencyProvider.shared.appSettings
    private(set) var privacyStore = PrivacyUserDefaults()
    private lazy var featureFlagger = AppDependencyProvider.shared.featureFlagger
    private lazy var animator: FireButtonAnimator = FireButtonAnimator(appSettings: AppUserDefaults())
    private var legacyViewProvider: SettingsLegacyViewProvider
    private lazy var versionProvider: AppVersion = AppVersion.shared
    private let voiceSearchHelper: VoiceSearchHelperProtocol
    private let syncPausedStateManager: any SyncPausedStateManaging
    var emailManager: EmailManager { EmailManager() }
    private let historyManager: HistoryManaging
    let privacyProDataReporter: PrivacyProDataReporting?
    let textZoomCoordinator: TextZoomCoordinating
    let aiChatSettings: AIChatSettingsProvider
    let maliciousSiteProtectionPreferencesManager: MaliciousSiteProtectionPreferencesManaging
    let experimentalThemingManager: ExperimentalThemingManager
    var experimentalAIChatManager: ExperimentalAIChatManager
    private let duckPlayerSettings: DuckPlayerSettings
    let featureDiscovery: FeatureDiscovery

    // Subscription Dependencies
    let isAuthV2Enabled: Bool
    let subscriptionManagerV1: (any SubscriptionManager)?
    let subscriptionManagerV2: (any SubscriptionManagerV2)?
    let subscriptionAuthV1toV2Bridge: any SubscriptionAuthV1toV2Bridge
    let subscriptionFeatureAvailability: SubscriptionFeatureAvailability
    private var subscriptionSignOutObserver: Any?
    var duckPlayerContingencyHandler: DuckPlayerContingencyHandler {
        DefaultDuckPlayerContingencyHandler(privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager)
    }

    private enum UserDefaultsCacheKey: String, UserDefaultsCacheKeyStore {
        case subscriptionState = "com.duckduckgo.ios.subscription.state"
    }
    // Used to cache the lasts subscription state for up to a week
    private let subscriptionStateCache = UserDefaultsCache<SettingsState.Subscription>(key: UserDefaultsCacheKey.subscriptionState,
                                                                         settings: UserDefaultsCacheSettings(defaultExpirationInterval: .days(7)))
    // Properties
    private lazy var isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var cancellables = Set<AnyCancellable>()

    // App Data State Notification Observer
    private var appDataClearingObserver: Any?
    private var textZoomObserver: Any?

    // Closures to interact with legacy view controllers through the container
    var onRequestPushLegacyView: ((UIViewController) -> Void)?
    var onRequestPresentLegacyView: ((UIViewController, _ modal: Bool) -> Void)?
    var onRequestPopLegacyView: (() -> Void)?
    var onRequestDismissSettings: (() -> Void)?

    // View State
    @Published private(set) var state: SettingsState

    // MARK: Cell Visibility
    enum Features {
        case sync
        case autofillAccessCredentialManagement
        case zoomLevel
        case voiceSearch
        case addressbarPosition
        case speechRecognition
        case networkProtection
    }

    var shouldShowNoMicrophonePermissionAlert: Bool = false
    @Published var shouldShowEmailAlert: Bool = false

    @Published var shouldShowRecentlyVisitedSites: Bool = true

    @Published var isInternalUser: Bool = AppDependencyProvider.shared.internalUserDecider.isInternalUser

    @Published var selectedFeedbackFlow: String?

    // MARK: - Deep linking
    // Used to automatically navigate to a specific section
    // immediately after loading the Settings View
    @Published private(set) var deepLinkTarget: SettingsDeepLinkSection?

    // MARK: Bindings

    var themeStyleBinding: Binding<ThemeStyle> {
        Binding<ThemeStyle>(
            get: { self.state.appThemeStyle },
            set: {
                Pixel.fire(pixel: .settingsThemeSelectorPressed)
                self.state.appThemeStyle = $0
                ThemeManager.shared.setThemeStyle($0)
            }
        )
    }
    var fireButtonAnimationBinding: Binding<FireButtonAnimationType> {
        Binding<FireButtonAnimationType>(
            get: { self.state.fireButtonAnimation },
            set: {
                Pixel.fire(pixel: .settingsFireButtonSelectorPressed)
                self.appSettings.currentFireButtonAnimation = $0
                self.state.fireButtonAnimation = $0
                NotificationCenter.default.post(name: AppUserDefaults.Notifications.currentFireButtonAnimationChange, object: self)
                self.animator.animate {
                    // no op
                } onTransitionCompleted: {
                    // no op
                } completion: {
                    // no op
                }
            }
        )
    }

    var addressBarPositionBinding: Binding<AddressBarPosition> {
        Binding<AddressBarPosition>(
            get: {
                self.state.addressBar.position
            },
            set: {
                Pixel.fire(pixel: $0 == .top ? .settingsAddressBarTopSelected : .settingsAddressBarBottomSelected)
                self.appSettings.currentAddressBarPosition = $0
                self.state.addressBar.position = $0
            }
        )
    }

    var addressBarShowsFullURL: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.showsFullURL },
            set: {
                Pixel.fire(pixel: $0 ? .settingsShowFullURLOn : .settingsShowFullURLOff)
                self.state.showsFullURL = $0
                self.appSettings.showFullSiteAddress = $0
            }
        )
    }

    var experimentalThemingBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.isExperimentalThemingEnabled },
            set: { _ in
                self.experimentalThemingManager.toggleExperimentalTheming()
                self.state.isExperimentalThemingEnabled = self.experimentalThemingManager.isExperimentalThemingEnabled
            })
    }


    var applicationLockBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.applicationLock },
            set: {
                self.privacyStore.authenticationEnabled = $0
                self.state.applicationLock = $0
            }
        )
    }

    var autocompleteGeneralBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.autocomplete },
            set: {
                self.appSettings.autocomplete = $0
                self.state.autocomplete = $0
                self.clearHistoryIfNeeded()
                self.updateRecentlyVisitedSitesVisibility()
                
                if $0 {
                    Pixel.fire(pixel: .settingsGeneralAutocompleteOn)
                } else {
                    Pixel.fire(pixel: .settingsGeneralAutocompleteOff)
                }
            }
        )
    }

    var autocompletePrivateSearchBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.autocomplete },
            set: {
                self.appSettings.autocomplete = $0
                self.state.autocomplete = $0
                self.clearHistoryIfNeeded()
                self.updateRecentlyVisitedSitesVisibility()

                if $0 {
                    Pixel.fire(pixel: .settingsPrivateSearchAutocompleteOn)
                } else {
                    Pixel.fire(pixel: .settingsPrivateSearchAutocompleteOff)
                }
            }
        )
    }

    var autocompleteRecentlyVisitedSitesBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.recentlyVisitedSites },
            set: {
                self.appSettings.recentlyVisitedSites = $0
                self.state.recentlyVisitedSites = $0
                if $0 {
                    Pixel.fire(pixel: .settingsRecentlyVisitedOn)
                } else {
                    Pixel.fire(pixel: .settingsRecentlyVisitedOff)
                }
                self.clearHistoryIfNeeded()
            }
        )
    }

    var gpcBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.sendDoNotSell },
            set: {
                self.appSettings.sendDoNotSell = $0
                self.state.sendDoNotSell = $0
                NotificationCenter.default.post(name: AppUserDefaults.Notifications.doNotSellStatusChange, object: nil)
                if $0 {
                    Pixel.fire(pixel: .settingsGpcOn)
                } else {
                    Pixel.fire(pixel: .settingsGpcOff)
                }
            }
        )
    }

    var autoconsentBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.autoconsentEnabled },
            set: {
                self.appSettings.autoconsentEnabled = $0
                self.state.autoconsentEnabled = $0
                if $0 {
                    Pixel.fire(pixel: .settingsAutoconsentOn)
                } else {
                    Pixel.fire(pixel: .settingsAutoconsentOff)
                }
            }
        )
    }

    var voiceSearchEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.voiceSearchEnabled },
            set: { newValue in
                self.setVoiceSearchEnabled(to: newValue)
                if newValue {
                    Pixel.fire(pixel: .settingsVoiceSearchOn)
                } else {
                    Pixel.fire(pixel: .settingsVoiceSearchOff)
                }
            }
        )
    }

    var textZoomLevelBinding: Binding<TextZoomLevel> {
        Binding<TextZoomLevel>(
            get: { self.state.textZoom.level },
            set: { newValue in
                Pixel.fire(.settingsAccessiblityTextZoom, withAdditionalParameters: [
                    PixelParameters.textZoomInitial: String(self.appSettings.defaultTextZoomLevel.rawValue),
                    PixelParameters.textZoomUpdated: String(newValue.rawValue),
                ])
                self.appSettings.defaultTextZoomLevel = newValue
                self.state.textZoom.level = newValue
            }
        )
    }

    var duckPlayerModeBinding: Binding<DuckPlayerMode> {
        Binding<DuckPlayerMode>(
            get: {
                return self.state.duckPlayerMode ?? .alwaysAsk
            },
            set: {
                self.appSettings.duckPlayerMode = $0
                self.state.duckPlayerMode = $0
                
                switch self.state.duckPlayerMode {
                case .alwaysAsk:
                    Pixel.fire(pixel: Pixel.Event.duckPlayerSettingBackToDefault)
                case .disabled:
                    Pixel.fire(pixel: Pixel.Event.duckPlayerSettingNeverSettings)
                case .enabled:
                    Pixel.fire(pixel: Pixel.Event.duckPlayerSettingAlwaysSettings)
                default:
                    break
                }
            }
        )
    }
    
    var duckPlayerOpenInNewTabBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.duckPlayerOpenInNewTab },
            set: {
                self.appSettings.duckPlayerOpenInNewTab = $0
                self.state.duckPlayerOpenInNewTab = $0
                if self.state.duckPlayerOpenInNewTab {
                    Pixel.fire(pixel: Pixel.Event.duckPlayerNewTabSettingOn)
                } else {
                    Pixel.fire(pixel: Pixel.Event.duckPlayerNewTabSettingOff)
                }
            }
        )
    }
    
    var duckPlayerNativeUI: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.duckPlayerNativeUI },
            set: {
                self.appSettings.duckPlayerNativeUI = $0
                self.state.duckPlayerNativeUI = $0
            }
        )
    }
    
    var duckPlayerAutoplay: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.duckPlayerAutoplay },
            set: {
                self.appSettings.duckPlayerAutoplay = $0
                self.state.duckPlayerAutoplay = $0
            }
        )
    }

    var duckPlayerNativeUISERPEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.duckPlayerNativeUISERPEnabled },
            set: {
                self.appSettings.duckPlayerNativeUISERPEnabled = $0
                self.state.duckPlayerNativeUISERPEnabled = $0
            }
        )
    }

      var duckPlayerNativeYoutubeModeBinding: Binding<NativeDuckPlayerYoutubeMode> {
        Binding<NativeDuckPlayerYoutubeMode>(
            get: {
                return self.state.duckPlayerNativeYoutubeMode
            },
            set: {
                self.appSettings.duckPlayerNativeYoutubeMode = $0
                self.state.duckPlayerNativeYoutubeMode = $0
            }
        )
    }

    var duckPlayerVariantBinding: Binding<DuckPlayerVariant> {
        Binding<DuckPlayerVariant>(
            get: {
                return self.duckPlayerSettings.variant
            },
            set: {
                self.duckPlayerSettings.variant = $0
            }
        )
    }

    func setVoiceSearchEnabled(to value: Bool) {
        if value {
            enableVoiceSearch { [weak self] result in
                DispatchQueue.main.async {
                    self?.state.voiceSearchEnabled = result
                    self?.voiceSearchHelper.enableVoiceSearch(true)
                    if !result {
                        // Permission is denied
                        self?.shouldShowNoMicrophonePermissionAlert = true
                    }
                }
            }
        } else {
            voiceSearchHelper.enableVoiceSearch(false)
            state.voiceSearchEnabled = false
        }
    }

    var longPressBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.longPressPreviews },
            set: {
                self.appSettings.longPressPreviews = $0
                self.state.longPressPreviews = $0
            }
        )
    }

    var universalLinksBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.allowUniversalLinks },
            set: {
                self.appSettings.allowUniversalLinks = $0
                self.state.allowUniversalLinks = $0
            }
        )
    }

    var crashCollectionOptInStatusBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.crashCollectionOptInStatus == .optedIn },
            set: {
                if self.appSettings.crashCollectionOptInStatus == .optedIn && $0 == false {
                    let crashCollection = CrashCollection(crashReportSender: CrashReportSender(platform: .iOS, pixelEvents: CrashReportSender.pixelEvents))
                    crashCollection.clearCRCID()
                }
                self.appSettings.crashCollectionOptInStatus = $0 ? .optedIn : .optedOut
                self.state.crashCollectionOptInStatus = $0 ? .optedIn : .optedOut
            }
        )
    }

    var cookiePopUpProtectionStatus: StatusIndicator {
        return appSettings.autoconsentEnabled ? .on : .off
    }
    
    var emailProtectionStatus: StatusIndicator {
        return emailManager.isSignedIn ? .on : .off
    }
    
    var syncStatus: StatusIndicator {
        legacyViewProvider.syncService.authState != .inactive ? .on : .off
    }

    var enablesUnifiedFeedbackForm: Bool {
        subscriptionAuthV1toV2Bridge.isUserAuthenticated
    }

    // MARK: Default Init
    init(state: SettingsState? = nil,
         legacyViewProvider: SettingsLegacyViewProvider,
         isAuthV2Enabled: Bool,
         subscriptionManagerV1: (any SubscriptionManager)?,
         subscriptionManagerV2: (any SubscriptionManagerV2)?,
         subscriptionAuthV1toV2Bridge: any SubscriptionAuthV1toV2Bridge,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability,
         voiceSearchHelper: VoiceSearchHelperProtocol,
         variantManager: VariantManager = AppDependencyProvider.shared.variantManager,
         deepLink: SettingsDeepLinkSection? = nil,
         historyManager: HistoryManaging,
         syncPausedStateManager: any SyncPausedStateManaging,
         privacyProDataReporter: PrivacyProDataReporting,
         textZoomCoordinator: TextZoomCoordinating,
         aiChatSettings: AIChatSettingsProvider,
         maliciousSiteProtectionPreferencesManager: MaliciousSiteProtectionPreferencesManaging,
         experimentalThemingManager: ExperimentalThemingManager,
         experimentalAIChatManager: ExperimentalAIChatManager,
         duckPlayerSettings: DuckPlayerSettings = DuckPlayerSettingsDefault(),
         featureDiscovery: FeatureDiscovery = DefaultFeatureDiscovery()
    ) {

        self.state = SettingsState.defaults
        self.legacyViewProvider = legacyViewProvider
        self.isAuthV2Enabled = isAuthV2Enabled
        self.subscriptionManagerV1 = subscriptionManagerV1
        self.subscriptionManagerV2 = subscriptionManagerV2
        self.subscriptionAuthV1toV2Bridge = subscriptionAuthV1toV2Bridge
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.voiceSearchHelper = voiceSearchHelper
        self.deepLinkTarget = deepLink
        self.historyManager = historyManager
        self.syncPausedStateManager = syncPausedStateManager
        self.privacyProDataReporter = privacyProDataReporter
        self.textZoomCoordinator = textZoomCoordinator
        self.aiChatSettings = aiChatSettings
        self.maliciousSiteProtectionPreferencesManager = maliciousSiteProtectionPreferencesManager
        self.experimentalThemingManager = experimentalThemingManager
        self.experimentalAIChatManager = experimentalAIChatManager
        self.duckPlayerSettings = duckPlayerSettings
        self.featureDiscovery = featureDiscovery
        setupNotificationObservers()
        updateRecentlyVisitedSitesVisibility()
    }

    deinit {
        subscriptionSignOutObserver = nil
        appDataClearingObserver = nil
        textZoomObserver = nil
    }
}

// MARK: Private methods
extension SettingsViewModel {
    
    // This manual (re)initialization will go away once appSettings and
    // other dependencies are observable (Such as AppIcon and netP)
    // and we can use subscribers (Currently called from the view onAppear)
    @MainActor
    private func initState() {
        self.state = SettingsState(
            appThemeStyle: appSettings.currentThemeStyle,
            appIcon: AppIconManager.shared.appIcon,
            fireButtonAnimation: appSettings.currentFireButtonAnimation,
            textZoom: SettingsState.TextZoom(enabled: textZoomCoordinator.isEnabled, level: appSettings.defaultTextZoomLevel),
            addressBar: SettingsState.AddressBar(enabled: !isPad, position: appSettings.currentAddressBarPosition),
            showsFullURL: appSettings.showFullSiteAddress,
            isExperimentalThemingEnabled: experimentalThemingManager.isExperimentalThemingEnabled,
            isExperimentalAIChatEnabled: experimentalAIChatManager.isExperimentalAIChatSettingsEnabled,
            sendDoNotSell: appSettings.sendDoNotSell,
            autoconsentEnabled: appSettings.autoconsentEnabled,
            autoclearDataEnabled: AutoClearSettingsModel(settings: appSettings) != nil,
            applicationLock: privacyStore.authenticationEnabled,
            autocomplete: appSettings.autocomplete,
            recentlyVisitedSites: appSettings.recentlyVisitedSites,
            longPressPreviews: appSettings.longPressPreviews,
            allowUniversalLinks: appSettings.allowUniversalLinks,
            activeWebsiteAccount: nil,
            version: versionProvider.versionAndBuildNumber,
            crashCollectionOptInStatus: appSettings.crashCollectionOptInStatus,
            debugModeEnabled: featureFlagger.isFeatureOn(.debugMenu) || isDebugBuild,
            voiceSearchEnabled: voiceSearchHelper.isVoiceSearchEnabled,
            speechRecognitionAvailable: voiceSearchHelper.isSpeechRecognizerAvailable,
            loginsEnabled: featureFlagger.isFeatureOn(.autofillAccessCredentialManagement),
            networkProtectionConnected: false,
            subscription: SettingsState.defaults.subscription,
            sync: getSyncState(),
            syncSource: nil,
            duckPlayerEnabled: featureFlagger.isFeatureOn(.duckPlayer) || shouldDisplayDuckPlayerContingencyMessage,
            duckPlayerMode: duckPlayerSettings.mode,
            duckPlayerOpenInNewTab: duckPlayerSettings.openInNewTab,
            duckPlayerOpenInNewTabEnabled: featureFlagger.isFeatureOn(.duckPlayerOpenInNewTab),
            duckPlayerNativeUI: duckPlayerSettings.nativeUI,
            duckPlayerAutoplay: duckPlayerSettings.autoplay,
            duckPlayerNativeUISERPEnabled: duckPlayerSettings.nativeUISERPEnabled,
            duckPlayerNativeYoutubeMode: duckPlayerSettings.nativeUIYoutubeMode
        )

        // Subscribe to DuckPlayerSettings updates
        duckPlayerSettings.duckPlayerSettingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateDuckPlayerState()
            }
            .store(in: &cancellables)

        updateRecentlyVisitedSitesVisibility()
        setupSubscribers()
        Task { await setupSubscriptionEnvironment() }
    }

    private func updateRecentlyVisitedSitesVisibility() {
        withAnimation {
            shouldShowRecentlyVisitedSites = historyManager.isHistoryFeatureEnabled() && state.autocomplete
        }
    }

    private func clearHistoryIfNeeded() {
        if !historyManager.isEnabledByUser {
            Task {
                await self.historyManager.removeAllHistory()
            }
        }
    }

    private func getSyncState() -> SettingsState.SyncSettings {
        SettingsState.SyncSettings(enabled: legacyViewProvider.syncService.featureFlags.contains(.userInterface),
                                   title: {
            let syncService = legacyViewProvider.syncService
            let isDataSyncingDisabled = !syncService.featureFlags.contains(.dataSyncing)
            && syncService.authState == .active
            if isDataSyncingDisabled
                || syncPausedStateManager.isSyncPaused
                || syncPausedStateManager.isSyncBookmarksPaused
                || syncPausedStateManager.isSyncCredentialsPaused {
                return "⚠️ \(UserText.settingsSync)"
            }
            return SyncUI_iOS.UserText.syncTitle
        }())
    }

    private func firePixel(_ event: Pixel.Event,
                           withAdditionalParameters params: [String: String] = [:]) {
        Pixel.fire(pixel: event, withAdditionalParameters: params)
    }
    
    private func enableVoiceSearch(completion: @escaping (Bool) -> Void) {
        SpeechRecognizer.requestMicAccess { permission in
            if !permission {
                completion(false)
                return
            }
            completion(true)
        }
    }

    private func updateNetPStatus(connectionStatus: ConnectionStatus) {
        switch connectionStatus {
        case .connected:
            self.state.networkProtectionConnected = true
        default:
            self.state.networkProtectionConnected = false
        }
    }
    
    // Function to update local state from DuckPlayerSettings
    private func updateDuckPlayerState() {
        state.duckPlayerMode = duckPlayerSettings.mode
        state.duckPlayerOpenInNewTab = duckPlayerSettings.openInNewTab
        state.duckPlayerNativeUI = duckPlayerSettings.nativeUI
        state.duckPlayerAutoplay = duckPlayerSettings.autoplay
        state.duckPlayerNativeUISERPEnabled = duckPlayerSettings.nativeUISERPEnabled
        state.duckPlayerNativeYoutubeMode = duckPlayerSettings.nativeUIYoutubeMode
    }
}

// MARK: Subscribers
extension SettingsViewModel {
    
    private func setupSubscribers() {

        AppDependencyProvider.shared.connectionObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateNetPStatus(connectionStatus: status)
            }
            .store(in: &cancellables)

    }
}

// MARK: Public Methods
extension SettingsViewModel {
    
    func onAppear() {
        Task {
            await initState()
            triggerDeepLinkNavigation(to: self.deepLinkTarget)
        }
    }
    
    func onDisappear() {
        self.deepLinkTarget = nil
    }
    
    func setAsDefaultBrowser() {
        Pixel.fire(pixel: .settingsSetAsDefault)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    @MainActor func shouldPresentLoginsViewWithAccount(accountDetails: SecureVaultModels.WebsiteAccount?, source: AutofillSettingsSource? = nil) {
        state.activeWebsiteAccount = accountDetails
        state.autofillSource = source
        
        presentLegacyView(.logins)
    }

    @MainActor func shouldPresentSyncViewWithSource(_ source: String? = nil) {
        state.syncSource = source
        presentLegacyView(.sync)
    }

    func openEmailProtection() {
        UIApplication.shared.open(URL.emailProtectionQuickLink)
    }

    func openEmailAccountManagement() {
        UIApplication.shared.open(URL.emailProtectionAccountLink)
    }

    func openEmailSupport() {
        UIApplication.shared.open(URL.emailProtectionSupportLink)
    }

    func openOtherPlatforms() {
        UIApplication.shared.open(URL.otherDevices)
    }

    func openMoreSearchSettings() {
        Pixel.fire(pixel: .settingsMoreSearchSettings)
        UIApplication.shared.open(URL.searchSettings)
    }

    var shouldDisplayDuckPlayerContingencyMessage: Bool {
        duckPlayerContingencyHandler.shouldDisplayContingencyMessage
    }

    func openDuckPlayerContingencyMessageSite() {
        guard let url = duckPlayerContingencyHandler.learnMoreURL else { return }
        Pixel.fire(pixel: .duckPlayerContingencyLearnMoreClicked)
        UIApplication.shared.open(url)
    }

    @MainActor func openCookiePopupManagement() {
        pushViewController(legacyViewProvider.autoConsent)
    }
    
    @MainActor func dismissSettings() {
        onRequestDismissSettings?()
    }

}

// MARK: Legacy View Presentation
// Some UIKit views have visual issues when presented via UIHostingController so
// for all existing subviews, default to UIKit based presentation until we
// can review and migrate
extension SettingsViewModel {
    
    @MainActor func presentLegacyView(_ view: SettingsLegacyViewProvider.LegacyView) {
        
        switch view {
        
        case .addToDock:
            presentViewController(legacyViewProvider.addToDock, modal: true)
        case .sync:
            pushViewController(legacyViewProvider.syncSettings(source: state.syncSource))
        case .appIcon: pushViewController(legacyViewProvider.appIconSettings(onChange: { [weak self] appIcon in
            self?.state.appIcon = appIcon
        }))
        case .unprotectedSites: pushViewController(legacyViewProvider.unprotectedSites)
        case .fireproofSites: pushViewController(legacyViewProvider.fireproofSites)
        case .autoclearData:
            pushViewController(legacyViewProvider.autoclearData)
        case .keyboard: pushViewController(legacyViewProvider.keyboard)
        case .debug: pushViewController(legacyViewProvider.debug)
            
        case .feedback:
            presentViewController(legacyViewProvider.feedback, modal: false)
        case .logins:
            pushViewController(legacyViewProvider.loginSettings(delegate: self,
                                                                selectedAccount: state.activeWebsiteAccount,
                                                                source: state.autofillSource))

        case .gpc:
            firePixel(.settingsDoNotSellShown)
            pushViewController(legacyViewProvider.gpc)
        
        case .autoconsent:
            pushViewController(legacyViewProvider.autoConsent)
        }
    }
 
    @MainActor
    private func pushViewController(_ view: UIViewController) {
        onRequestPushLegacyView?(view)
    }
    
    @MainActor
    private func presentViewController(_ view: UIViewController, modal: Bool) {
        onRequestPresentLegacyView?(view, modal)
    }
    
}

// MARK: AutofillLoginSettingsListViewControllerDelegate
extension SettingsViewModel: AutofillSettingsViewControllerDelegate {
    
    @MainActor
    func autofillSettingsViewControllerDidFinish(_ controller: AutofillSettingsViewController) {
        onRequestPopLegacyView?()
    }
}

// MARK: DeepLinks
extension SettingsViewModel {

    enum SettingsDeepLinkSection: Identifiable, Equatable {
        case netP
        case dbp
        case itr
        case subscriptionFlow(redirectURLComponents: URLComponents? = nil)
        case restoreFlow
        case duckPlayer
        case aiChat
        // Add other cases as needed

        var id: String {
            switch self {
            case .netP: return "netP"
            case .dbp: return "dbp"
            case .itr: return "itr"
            case .subscriptionFlow: return "subscriptionFlow"
            case .restoreFlow: return "restoreFlow"
            case .duckPlayer: return "duckPlayer"
            case .aiChat: return "aiChat"
            // Ensure all cases are covered
            }
        }

        // Define the presentation type: .sheet or .push
        // Default to .sheet, specify .push where needed
        var type: DeepLinkType {
            switch self {
            case .netP, .dbp, .itr, .subscriptionFlow, .restoreFlow, .duckPlayer, .aiChat:
                return .navigationLink
            }
        }
    }

    // Define DeepLinkType outside the enum if not already defined
    enum DeepLinkType {
        case sheet
        case navigationLink
    }
            
    // Navigate to a section in settings
    func triggerDeepLinkNavigation(to target: SettingsDeepLinkSection?) {
        guard let target else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.deepLinkTarget = target
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.deepLinkTarget = nil
            }
        }
    }
}

// MARK: Subscriptions
extension SettingsViewModel {

    @MainActor
    private func setupSubscriptionEnvironment() async {
        // If there's cached data use it by default
        if let cachedSubscription = subscriptionStateCache.get() {
            state.subscription = cachedSubscription
        // Otherwise use defaults and setup purchase availability
        } else {
            state.subscription = SettingsState.defaults.subscription
        }

        // Update if can purchase based on App Store product availability
        state.subscription.canPurchase = subscriptionAuthV1toV2Bridge.canPurchase

        // Update if user is signed in based on the presence of token
        state.subscription.isSignedIn = subscriptionAuthV1toV2Bridge.isUserAuthenticated

        // Active subscription check
        guard let token = try? await subscriptionAuthV1toV2Bridge.getAccessToken() else {
            // Reset state in case cache was outdated
            state.subscription.hasSubscription = false
            state.subscription.hasActiveSubscription = false
            state.subscription.entitlements = []
            state.subscription.platform = .unknown
            state.subscription.isActiveTrialOffer = false

            subscriptionStateCache.set(state.subscription) // Sync cache
            return
        }
        
        do {
            let subscription = try await subscriptionAuthV1toV2Bridge.getSubscription(cachePolicy: .returnCacheDataElseLoad)
            state.subscription.platform = subscription.platform
            state.subscription.hasSubscription = true
            state.subscription.hasActiveSubscription = subscription.isActive
            state.subscription.isActiveTrialOffer = subscription.hasActiveTrialOffer

            // Check entitlements and update state
            var currentEntitlements: [Entitlement.ProductName] = []
            let entitlementsToCheck: [Entitlement.ProductName] = [.networkProtection, .dataBrokerProtection, .identityTheftRestoration, .identityTheftRestorationGlobal]

            for entitlement in entitlementsToCheck {
                if let hasEntitlement = try? await subscriptionAuthV1toV2Bridge.isEnabled(feature: entitlement),
                    hasEntitlement {
                    currentEntitlements.append(entitlement)
                }
            }

            self.state.subscription.entitlements = currentEntitlements
            self.state.subscription.subscriptionFeatures = await subscriptionAuthV1toV2Bridge.currentSubscriptionFeatures()
        } catch SubscriptionEndpointServiceError.noData {
            Logger.subscription.debug("No subscription data available")
            state.subscription.hasSubscription = false
            state.subscription.hasActiveSubscription = false
            state.subscription.entitlements = []
            state.subscription.platform = .unknown
            state.subscription.isActiveTrialOffer = false

            DailyPixel.fireDailyAndCount(pixel: .settingsPrivacyProAccountWithNoSubscriptionFound)
        } catch {
            Logger.subscription.error("Failed to fetch Subscription: \(error, privacy: .public)")
        }

        // Sync Cache
        subscriptionStateCache.set(state.subscription)
    }
    
    private func setupNotificationObservers() {
        subscriptionSignOutObserver = NotificationCenter.default.addObserver(forName: .accountDidSignOut,
                                                                             object: nil,
                                                                             queue: .main) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task {
                strongSelf.subscriptionStateCache.reset()
                await strongSelf.setupSubscriptionEnvironment()
            }
        }
        
        // Observe App Data clearing state
        appDataClearingObserver = NotificationCenter.default.addObserver(forName: AppUserDefaults.Notifications.appDataClearingUpdated,
                                                                         object: nil,
                                                                         queue: .main) { [weak self] _ in
            guard let settings = self?.appSettings else { return }
            self?.state.autoclearDataEnabled = (AutoClearSettingsModel(settings: settings) != nil)
        }
        
        textZoomObserver = NotificationCenter.default.addObserver(forName: AppUserDefaults.Notifications.textZoomChange,
                                                                  object: nil,
                                                                  queue: .main, using: { [weak self] _ in
            guard let self = self else { return }
            self.state.textZoom = SettingsState.TextZoom(enabled: true, level: self.appSettings.defaultTextZoomLevel)
        })
    }

    func restoreAccountPurchase() async {
        if !isAuthV2Enabled {
            await restoreAccountPurchaseV1()
        } else {
            await restoreAccountPurchaseV2()
        }
    }

    func restoreAccountPurchaseV1() async {
        guard let subscriptionManagerV1 else {
            assertionFailure("Missing dependency: subscriptionManagerV1")
            return
        }

        DispatchQueue.main.async { self.state.subscription.isRestoring = true }
        let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(accountManager: subscriptionManagerV1.accountManager,
                                                             storePurchaseManager: subscriptionManagerV1.storePurchaseManager(),
                                                             subscriptionEndpointService: subscriptionManagerV1.subscriptionEndpointService,
                                                             authEndpointService: subscriptionManagerV1.authEndpointService)
        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
        switch result {
        case .success:
            DispatchQueue.main.async {
                self.state.subscription.isRestoring = false
            }
            await self.setupSubscriptionEnvironment()
            
        case .failure(let restoreFlowError):
            DispatchQueue.main.async {
                self.state.subscription.isRestoring = false
                self.state.subscription.shouldDisplayRestoreSubscriptionError = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.state.subscription.shouldDisplayRestoreSubscriptionError = false
                }
            }

            switch restoreFlowError {
            case .missingAccountOrTransactions:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorMissingAccountOrTransactions)
            case .pastTransactionAuthenticationError:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorPastTransactionAuthenticationError)
            case .failedToObtainAccessToken:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToObtainAccessToken)
            case .failedToFetchAccountDetails:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToFetchAccountDetails)
            case .failedToFetchSubscriptionDetails:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToFetchSubscriptionDetails)
            case .subscriptionExpired:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorSubscriptionExpired)
            }
        }
    }

    func restoreAccountPurchaseV2() async {

        guard let subscriptionManagerV2 else {
            assertionFailure("Missing dependency: subscriptionManagerV2")
            return
        }

        DispatchQueue.main.async { self.state.subscription.isRestoring = true }

        let appStoreRestoreFlow = DefaultAppStoreRestoreFlowV2(subscriptionManager: subscriptionManagerV2,
                                                             storePurchaseManager: subscriptionManagerV2.storePurchaseManager())
        let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
        switch result {
        case .success:
            DispatchQueue.main.async {
                self.state.subscription.isRestoring = false
            }
            await self.setupSubscriptionEnvironment()

        case .failure(let restoreFlowError):
            DispatchQueue.main.async {
                self.state.subscription.isRestoring = false
                self.state.subscription.shouldDisplayRestoreSubscriptionError = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.state.subscription.shouldDisplayRestoreSubscriptionError = false
                }
            }

            switch restoreFlowError {
            case .missingAccountOrTransactions:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorMissingAccountOrTransactions)
            case .pastTransactionAuthenticationError:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorPastTransactionAuthenticationError)
            case .failedToObtainAccessToken:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToObtainAccessToken)
            case .failedToFetchAccountDetails:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToFetchAccountDetails)
            case .failedToFetchSubscriptionDetails:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorFailedToFetchSubscriptionDetails)
            case .subscriptionExpired:
                DailyPixel.fireDailyAndCount(pixel: .privacyProActivatingRestoreErrorSubscriptionExpired)
            }
        }
    }

}

// Deeplink notification handling
extension NSNotification.Name {
    static let settingsDeepLinkNotification: NSNotification.Name = Notification.Name(rawValue: "com.duckduckgo.notification.settingsDeepLink")
}

// MARK: - AI Chat
extension SettingsViewModel {

    var isAiChatEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.aiChatSettings.isAIChatEnabled },
            set: { newValue in
                withAnimation {
                    self.objectWillChange.send()
                    self.aiChatSettings.enableAIChat(enable: newValue)
                }
            }
        )
    }

    var aiChatBrowsingMenuEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.aiChatSettings.isAIChatBrowsingMenuUserSettingsEnabled },
            set: { newValue in
                self.aiChatSettings.enableAIChatBrowsingMenuUserSettings(enable: newValue)
            }
        )
    }

    var aiChatAddressBarEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.aiChatSettings.isAIChatAddressBarUserSettingsEnabled },
            set: { newValue in
                self.aiChatSettings.enableAIChatAddressBarUserSettings(enable: newValue)
            }
        )
    }

    var aiChatVoiceSearchEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.aiChatSettings.isAIChatVoiceSearchUserSettingsEnabled },
            set: { newValue in
                self.aiChatSettings.enableAIChatVoiceSearchUserSettings(enable: newValue)
            }
        )
    }

    var aiChatTabSwitcherEnabledBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.aiChatSettings.isAIChatTabSwitcherUserSettingsEnabled },
            set: { newValue in
                self.aiChatSettings.enableAIChatTabSwitcherUserSettings(enable: newValue)
            }
        )
    }

    var aiChatExperimentalBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.state.isExperimentalAIChatEnabled },
            set: { _ in
                self.experimentalAIChatManager.toggleExperimentalTheming()
                self.state.isExperimentalAIChatEnabled = self.experimentalAIChatManager.isExperimentalAIChatSettingsEnabled
            })
    }

}
