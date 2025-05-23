//
//  TabManager.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import Common
import Core
import DDGSync
import WebKit
import BrowserServicesKit
import Persistence
import History
import Subscription
import os.log

class TabManager {

    private(set) var model: TabsModel
    private(set) var persistence: TabsModelPersisting

    private var tabControllerCache = [TabViewController]()

    private let bookmarksDatabase: CoreDataDatabase
    private let historyManager: HistoryManaging
    private let syncService: DDGSyncing
    private var previewsSource: TabPreviewsSource
    private let interactionStateSource: TabInteractionStateSource?
    private var duckPlayer: DuckPlayerControlling
    private var privacyProDataReporter: PrivacyProDataReporting
    private let contextualOnboardingPresenter: ContextualOnboardingPresenting
    private let contextualOnboardingLogic: ContextualOnboardingLogic
    private let onboardingPixelReporter: OnboardingPixelReporting
    private let featureFlagger: FeatureFlagger
    private let contentScopeExperimentManager: ContentScopeExperimentsManaging
    private let textZoomCoordinator: TextZoomCoordinating
    private let fireproofing: Fireproofing
    private let websiteDataManager: WebsiteDataManaging
    private let subscriptionCookieManager: SubscriptionCookieManaging
    private let appSettings: AppSettings
    private let maliciousSiteProtectionManager: MaliciousSiteProtectionManaging
    private let maliciousSiteProtectionPreferencesManager: MaliciousSiteProtectionPreferencesManaging
    private let featureDiscovery: FeatureDiscovery

    weak var delegate: TabDelegate?

    @UserDefaultsWrapper(key: .faviconTabsCacheNeedsCleanup, defaultValue: true)
    var tabsCacheNeedsCleanup: Bool

    @MainActor
    init(model: TabsModel,
         persistence: TabsModelPersisting,
         previewsSource: TabPreviewsSource,
         interactionStateSource: TabInteractionStateSource?,
         bookmarksDatabase: CoreDataDatabase,
         historyManager: HistoryManaging,
         syncService: DDGSyncing,
         duckPlayer: DuckPlayer = DuckPlayer(),
         privacyProDataReporter: PrivacyProDataReporting,
         contextualOnboardingPresenter: ContextualOnboardingPresenting,
         contextualOnboardingLogic: ContextualOnboardingLogic,
         onboardingPixelReporter: OnboardingPixelReporting,
         featureFlagger: FeatureFlagger,
         contentScopeExperimentManager: ContentScopeExperimentsManaging,
         subscriptionCookieManager: SubscriptionCookieManaging,
         appSettings: AppSettings,
         textZoomCoordinator: TextZoomCoordinating,
         websiteDataManager: WebsiteDataManaging,
         fireproofing: Fireproofing,
         maliciousSiteProtectionManager: MaliciousSiteProtectionManaging,
         maliciousSiteProtectionPreferencesManager: MaliciousSiteProtectionPreferencesManaging,
         featureDiscovery: FeatureDiscovery
    ) {
        self.model = model
        self.persistence = persistence
        self.previewsSource = previewsSource
        self.interactionStateSource = interactionStateSource
        self.bookmarksDatabase = bookmarksDatabase
        self.historyManager = historyManager
        self.syncService = syncService
        self.duckPlayer = duckPlayer
        self.privacyProDataReporter = privacyProDataReporter
        self.contextualOnboardingPresenter = contextualOnboardingPresenter
        self.contextualOnboardingLogic = contextualOnboardingLogic
        self.onboardingPixelReporter = onboardingPixelReporter
        self.featureFlagger = featureFlagger
        self.contentScopeExperimentManager = contentScopeExperimentManager
        self.subscriptionCookieManager = subscriptionCookieManager
        self.appSettings = appSettings
        self.textZoomCoordinator = textZoomCoordinator
        self.websiteDataManager = websiteDataManager
        self.fireproofing = fireproofing
        self.maliciousSiteProtectionManager = maliciousSiteProtectionManager
        self.maliciousSiteProtectionPreferencesManager = maliciousSiteProtectionPreferencesManager
        self.featureDiscovery = featureDiscovery
        registerForNotifications()
    }

    @MainActor
    private func buildController(forTab tab: Tab, inheritedAttribution: AdClickAttributionLogic.State?, interactionState: Data?) -> TabViewController {
        let url = tab.link?.url
        return buildController(forTab: tab, url: url, inheritedAttribution: inheritedAttribution, interactionState: interactionState)
    }

    @MainActor
    private func buildController(forTab tab: Tab,
                                 url: URL?,
                                 inheritedAttribution: AdClickAttributionLogic.State?,
                                 interactionState: Data?) -> TabViewController {
        let configuration =  WKWebViewConfiguration.persistent()

        let specialErrorPageNavigationHandler = SpecialErrorPageNavigationHandler(
            maliciousSiteProtectionNavigationHandler: MaliciousSiteProtectionNavigationHandler(
                maliciousSiteProtectionManager: maliciousSiteProtectionManager
            )
        )

        let controller = TabViewController.loadFromStoryboard(model: tab,
                                                              bookmarksDatabase: bookmarksDatabase,
                                                              historyManager: historyManager,
                                                              syncService: syncService,
                                                              duckPlayer: duckPlayer,
                                                              privacyProDataReporter: privacyProDataReporter,
                                                              contextualOnboardingPresenter: contextualOnboardingPresenter,
                                                              contextualOnboardingLogic: contextualOnboardingLogic,
                                                              onboardingPixelReporter: onboardingPixelReporter,
                                                              featureFlagger: featureFlagger,
                                                              contentScopeExperimentManager: contentScopeExperimentManager,
                                                              subscriptionCookieManager: subscriptionCookieManager,
                                                              textZoomCoordinator: textZoomCoordinator,
                                                              websiteDataManager: websiteDataManager,
                                                              fireproofing: fireproofing,
                                                              tabInteractionStateSource: interactionStateSource,
                                                              specialErrorPageNavigationHandler: specialErrorPageNavigationHandler,
                                                              featureDiscovery: featureDiscovery)
        controller.applyInheritedAttribution(inheritedAttribution)
        controller.attachWebView(configuration: configuration,
                                 interactionStateData: interactionState,
                                 andLoadRequest: url == nil ? nil : URLRequest.userInitiated(url!),
                                 consumeCookies: !model.hasActiveTabs)
        controller.delegate = delegate
        controller.loadViewIfNeeded()
        return controller
    }

    @MainActor
    func current(createIfNeeded: Bool = false) -> TabViewController? {
        guard let tab = model.currentTab else { return nil }

        if let controller = controller(for: tab) {
            return controller
        } else if createIfNeeded {
            Logger.general.debug("Tab not in cache, creating")
            let tabInteractionState = interactionStateSource?.popLastStateForTab(tab)
            let controller = buildController(forTab: tab, inheritedAttribution: nil, interactionState: tabInteractionState)
            tabControllerCache.append(controller)
            return controller
        } else {
            return nil
        }
    }
    
    func controller(for tab: Tab) -> TabViewController? {
        return tabControllerCache.first { $0.tabModel === tab }
    }

    var isEmpty: Bool {
        return tabControllerCache.isEmpty
    }
    
    var hasUnread: Bool {
        return model.hasUnread
    }

    var count: Int {
        return model.count
    }

    @MainActor
    func select(tabAt index: Int) -> TabViewController {
        current()?.dismiss()
        model.select(tabAt: index)

        save()
        return current(createIfNeeded: true)!
    }

    func addURLRequest(_ request: URLRequest?,
                       with configuration: WKWebViewConfiguration,
                       inheritedAttribution: AdClickAttributionLogic.State?) -> TabViewController {

        guard let configCopy = configuration.copy() as? WKWebViewConfiguration else {
            fatalError("Failed to copy configuration")
        }

        let tab: Tab
        if let request {
            tab = Tab(link: request.url == nil ? nil : Link(title: nil, url: request.url!))
        } else {
            tab = Tab()
        }
        model.insert(tab: tab, at: model.currentIndex + 1)
        model.select(tabAt: model.currentIndex + 1)

        let specialErrorPageNavigationHandler = SpecialErrorPageNavigationHandler(
            maliciousSiteProtectionNavigationHandler: MaliciousSiteProtectionNavigationHandler(
                maliciousSiteProtectionManager: maliciousSiteProtectionManager
            )
        )

        let controller = TabViewController.loadFromStoryboard(model: tab,
                                                              bookmarksDatabase: bookmarksDatabase,
                                                              historyManager: historyManager,
                                                              syncService: syncService,
                                                              duckPlayer: duckPlayer,
                                                              privacyProDataReporter: privacyProDataReporter,
                                                              contextualOnboardingPresenter: contextualOnboardingPresenter,
                                                              contextualOnboardingLogic: contextualOnboardingLogic,
                                                              onboardingPixelReporter: onboardingPixelReporter,
                                                              featureFlagger: featureFlagger,
                                                              contentScopeExperimentManager: contentScopeExperimentManager, subscriptionCookieManager: subscriptionCookieManager,
                                                              textZoomCoordinator: textZoomCoordinator,
                                                              websiteDataManager: websiteDataManager,
                                                              fireproofing: fireproofing,
                                                              tabInteractionStateSource: interactionStateSource,
                                                              specialErrorPageNavigationHandler: specialErrorPageNavigationHandler,
                                                              featureDiscovery: featureDiscovery)
        controller.attachWebView(configuration: configCopy,
                                 andLoadRequest: request,
                                 consumeCookies: !model.hasActiveTabs,
                                 loadingInitiatedByParentTab: true)
        controller.delegate = delegate
        controller.loadViewIfNeeded()
        controller.applyInheritedAttribution(inheritedAttribution)
        tabControllerCache.append(controller)

        save()
        return controller
    }

    func addHomeTab() {
        model.add(tab: Tab())
        model.select(tabAt: model.count - 1)
        save()
    }

    func firstHomeTab() -> Tab? {
        return model.tabs.first(where: { $0.link == nil })
    }

    func first(withId id: String) -> Tab? {
        return model.tabs.first { $0.uid == id }
    }

    func first(withUrl url: URL) -> Tab? {
        return model.tabs.first(where: {
            guard let linkUrl = $0.link?.url else { return false }

            if linkUrl == url {
                return true
            }

            if linkUrl.scheme == "https" && url.scheme == "http" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"
                return components?.url == linkUrl
            }

            return false
        })
    }

    func selectTab(_ tab: Tab) {
        guard let index = model.indexOf(tab: tab) else { return }
        model.select(tabAt: index)
        save()
    }

    @MainActor
    func add(url: URL?, inBackground: Bool = false, inheritedAttribution: AdClickAttributionLogic.State?) -> TabViewController {

        if !inBackground {
            current()?.dismiss()
        }

        let link = url == nil ? nil : Link(title: nil, url: url!)
        let tab = Tab(link: link)
        let controller = buildController(forTab: tab, url: url, inheritedAttribution: inheritedAttribution, interactionState: nil)
        tabControllerCache.append(controller)

        let index = model.currentIndex
        model.insert(tab: tab, at: index + 1)

        if !inBackground {
            model.select(tabAt: index + 1)
        }

        save()
        return controller
    }

    /// Warning! This will leave the underlying tabs empty.  This is intentional so that the the
    ///  Tab Switcher's UICollectionView 'delete items' function doesn't complain about mis-matching
    ///   number of items.
    func bulkRemoveTabs(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            let tab = model.get(tabAt: $0.row)
            previewsSource.removePreview(forTab: tab)
            if let controller = controller(for: tab) {
                removeFromCache(controller)
            }
            interactionStateSource?.removeStateForTab(tab)
        }
        model.remove(indexPaths)
        save()
    }

    func remove(at index: Int) {
        let tab = model.get(tabAt: index)
        previewsSource.removePreview(forTab: tab)
        model.remove(tab: tab)
        if let controller = controller(for: tab) {
            removeFromCache(controller)
        }
        interactionStateSource?.removeStateForTab(tab)
        save()
    }

    func replaceTab(at index: Int, withNewTab newTab: Tab) {
        // Removing a Tab automatically inserts a new one if tabs are empty. Hence add a new one only if needed
        if model.tabs.count == 1 {
            // Since we're not re-inserting we should use the proper removal to ensure
            //  things are cleaned up properly.
            remove(at: index)
        } else {
            model.remove(at: index)
            model.insert(tab: newTab, at: index)
        }
        save()
    }

    private func removeFromCache(_ controller: TabViewController) {
        if let index = tabControllerCache.firstIndex(of: controller) {
            tabControllerCache.remove(at: index)
        }
        controller.dismiss()
    }

    func removeAll() {
        previewsSource.removeAllPreviews()
        model.clearAll()
        for controller in tabControllerCache {
            removeFromCache(controller)
        }
        interactionStateSource?.removeAll(excluding: [])
        save()
    }

    func removeLeftoverInteractionStates() {
        interactionStateSource?.removeAll(excluding: model.tabs)
    }

    @MainActor
    func invalidateCache(forController controller: TabViewController) {
        if current() === controller {
            Pixel.fire(pixel: .webKitTerminationDidReloadCurrentTab)
            current()?.reload()
        } else {
            removeFromCache(controller)
        }
    }

    func save() {
        persistence.save(model: model)
    }
    
    @MainActor
    func prepareAllTabsExceptCurrentForDataClearing() {
        tabControllerCache.filter { $0 !== current() }.forEach { $0.prepareForDataClearing() }
    }
    
    @MainActor
    func prepareCurrentTabForDataClearing() {
        current()?.prepareForDataClearing()
    }

    func cleanupTabsFaviconCache() {
        guard tabsCacheNeedsCleanup else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self,
                  let tabsCacheUrl = FaviconsCacheType.tabs.cacheLocation()?.appendingPathComponent(Favicons.Constants.tabsCachePath),
                  let contents = try? FileManager.default.contentsOfDirectory(at: tabsCacheUrl, includingPropertiesForKeys: nil, options: []),
                    !contents.isEmpty else { return }

            let imageDomainURLs = contents.compactMap({ $0.filename })

            // create a Set of all unique hosts in case there are hundreds of tabs with many duplicate hosts
            let tabLink = Set(self.model.tabs.compactMap { tab in
                if let host = tab.link?.url.host {
                    return host
                }

                return nil
            })

            // hash the unique tab hosts
            let tabLinksHashed = tabLink.map { FaviconHasher.createHash(ofDomain: $0) }

            // filter images that don't have a corresponding tab
            let toDelete = imageDomainURLs.filter { !tabLinksHashed.contains($0) }
            toDelete.forEach {
                Favicons.shared.removeTabFavicon(forCacheKey: $0)
            }

            self.tabsCacheNeedsCleanup = false
        }
    }
}


// MARK: - Debugging Pixels

extension TabManager {

    fileprivate func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onApplicationBecameActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc
    private func onApplicationBecameActive(_ notification: NSNotification) {
        assertTabPreviewCount()
    }

    private func assertTabPreviewCount() {
        let totalStoredPreviews = previewsSource.totalStoredPreviews()
        let totalTabs = model.tabs.count

        if let storedPreviews = totalStoredPreviews, storedPreviews > totalTabs {
            Pixel.fire(pixel: .cachedTabPreviewsExceedsTabCount, withAdditionalParameters: [
                PixelParameters.tabPreviewCountDelta: "\(storedPreviews - totalTabs)"
            ])
            Task(priority: .utility) {
                await previewsSource.removePreviewsWithIdNotIn(Set(model.tabs.map { $0.uid }))
            }
        }
    }

}
