//
//  TabViewControllerBrowsingMenuExtension.swift
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

import UIKit
import Core
import BrowserServicesKit
import Bookmarks
import simd
import WidgetKit
import Common
import PrivacyDashboard
import PixelExperimentKit

extension TabViewController {

    private enum ShortcutEntriesState {
        case newTab
        case pageLoaded
    }

    private var shouldShowAIChatInMenu: Bool {
        let settings = AIChatSettings(privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager)
        return settings.isAIChatBrowsingMenuUserSettingsEnabled
    }

    private var shouldShowCopyButtonInBrowsingMenuList: Bool { shouldShowAIChatInMenu }

    func buildBrowsingMenuHeaderContent() -> [BrowsingMenuEntry] {
        var entries = [BrowsingMenuEntry]()

        let newTabEntry = BrowsingMenuEntry.regular(name: UserText.actionNewTab,
                                                    accessibilityLabel: UserText.keyCommandNewTab,
                                                    image: UIImage(named: "Add-24")!,
                                                    action: { [weak self] in
            self?.onNewTabAction()
        })

        let shareEntry = BrowsingMenuEntry.regular(name: UserText.actionShare, image: UIImage(named: "Share-24")!, action: { [weak self] in
            guard let self = self else { return }
            guard let menu = self.chromeDelegate?.omniBar.barView.menuButton else { return }
            Pixel.fire(pixel: .browsingMenuShare)
            self.onShareAction(forLink: self.link!, fromView: menu)
        })

        let copyEntry = buildCopyEntry(smallIcon: false)

        let reloadEntry = BrowsingMenuEntry.regular(name: UserText.actionRefresh, image: UIImage(named: "Reload-24")!, action: { [weak self] in
            guard let self = self else { return }
            Pixel.fire(pixel: .browsingMenuReload)
            self.reload()
        })

        let chatEntry = BrowsingMenuEntry.regular(name: UserText.actionOpenAIChat, image: UIImage(named: "AIChat-24")!, action: { [weak self] in
            Pixel.fire(pixel: .browsingMenuAIChat,
                       withAdditionalParameters: self?.featureDiscovery.addToParams([:], forFeature: .aiChat) ?? [:])
            self?.openAIChat()
        })

        if shouldShowAIChatInMenu {
            entries.append(newTabEntry)
            entries.append(chatEntry)
            entries.append(reloadEntry)
            entries.append(shareEntry)
        } else {
            entries.append(newTabEntry)
            entries.append(reloadEntry)
            entries.append(copyEntry)
            entries.append(shareEntry)
        }

        return entries
    }


    var favoriteEntryIndex: Int { 1 }

    func buildShortcutsMenu() -> [BrowsingMenuEntry] {
        buildShortcutsEntries(state: .newTab)
    }

    func buildBrowsingMenu(with bookmarksInterface: MenuBookmarksInteracting) -> [BrowsingMenuEntry] {
        var entries = [BrowsingMenuEntry]()

        let linkEntries = buildLinkEntries(with: bookmarksInterface)
        entries.append(contentsOf: linkEntries)

        if shouldShowCopyButtonInBrowsingMenuList {
            entries.append(buildCopyEntry(smallIcon: true))
        }

        entries.append(.regular(name: UserText.actionPrintSite,
                                accessibilityLabel: UserText.actionPrintSite,
                                image: UIImage(named: "Print-16")!,
                                action: { [weak self] in
            Pixel.fire(pixel: .browsingMenuListPrint)
            self?.print()
        }))

        if let domain = self.privacyInfo?.domain {
            entries.append(self.buildToggleProtectionEntry(forDomain: domain))
        }

        if link != nil {
            let name = UserText.actionReportBrokenSite
            entries.append(BrowsingMenuEntry.regular(name: name,
                                                     image: UIImage(named: "Feedback-16")!,
                                                     action: { [weak self] in
                self?.onReportBrokenSiteAction()
            }))
        }

        // Do not add separator if there are no entries so far
        if entries.count > 0 {
            entries.append(.separator)
        }

        let shortcutsEntries = buildShortcutsEntries(state: .pageLoaded)
        entries.append(contentsOf: shortcutsEntries)

        return entries
    }

    private func buildShortcutsEntries(state: ShortcutEntriesState) -> [BrowsingMenuEntry] {
        var entries = [BrowsingMenuEntry]()

        if state == .newTab {
            entries.append(BrowsingMenuEntry.regular(name: UserText.actionTabNew,
                                                     image: UIImage(named: "Add-16")!,
                                                     action: { [weak self] in
                self?.onNewTabAction()
            }))

            if shouldShowAIChatInMenu {
                entries.append(BrowsingMenuEntry.regular(name: UserText.actionAIChatNew,
                                                         image: UIImage(named: "AIChat-16")!,
                                                         action: { [weak self] in
                    Pixel.fire(pixel: .browsingMenuListAIChat,
                               withAdditionalParameters: self?.featureDiscovery.addToParams([:], forFeature: .aiChat) ?? [:])
                    self?.openAIChat()
                }))
            }

            entries.append(.separator)
        }

        entries.append(buildOpenBookmarksEntry())

        if featureFlagger.isFeatureOn(.autofillAccessCredentialManagement) {
            entries.append(BrowsingMenuEntry.regular(name: UserText.actionAutofillLogins,
                                                     image: UIImage(named: "Key-16")!,
                                                     action: { [weak self] in
                self?.onOpenAutofillLoginsAction()
            }))
        }

        entries.append(BrowsingMenuEntry.regular(name: UserText.actionDownloads,
                                                 image: UIImage(named: "Downloads-16")!,
                                                 showNotificationDot: AppDependencyProvider.shared.downloadManager.unseenDownloadsAvailable,
                                                 action: { [weak self] in
            self?.onOpenDownloadsAction()
        }))

        entries.append(BrowsingMenuEntry.regular(name: UserText.actionSettings,
                                                 image: UIImage(named: "Settings-16")!,
                                                 action: { [weak self] in
            self?.onBrowsingSettingsAction()
        }))

        return entries
    }

    private func buildLinkEntries(with bookmarksInterface: MenuBookmarksInteracting) -> [BrowsingMenuEntry] {
        guard let link = link, !isError else { return [] }

        var entries = [BrowsingMenuEntry]()

        let bookmarkEntries = buildBookmarkEntries(for: link, with: bookmarksInterface)
        entries.append(bookmarkEntries.bookmark)
        assert(self.favoriteEntryIndex == entries.count, "Entry index should be in sync with entry placement")
        entries.append(bookmarkEntries.favorite)

        entries.append(.separator)

        if let entry = self.buildKeepSignInEntry(forLink: link) {
            entries.append(entry)
        }

        if let entry = self.buildUseNewDuckAddressEntry(forLink: link) {
            entries.append(entry)
        }

        if let entry = textZoomCoordinator.makeBrowsingMenuEntry(forLink: link, inController: self, forWebView: self.webView) {
            entries.append(entry)
        }

        let title = self.tabModel.isDesktop ? UserText.actionRequestMobileSite : UserText.actionRequestDesktopSite
        let image = self.tabModel.isDesktop ? UIImage(named: "Device-Mobile-16")! : UIImage(named: "Device-Desktop-16")!
        entries.append(BrowsingMenuEntry.regular(name: title, image: image, action: { [weak self] in
            self?.onToggleDesktopSiteAction(forUrl: link.url)
        }))

        entries.append(self.buildFindInPageEntry(forLink: link))
                
        return entries
    }

    private func buildKeepSignInEntry(forLink link: Link) -> BrowsingMenuEntry? {
        guard let domain = link.url.host, !link.url.isDuckDuckGo else { return nil }
        let isFireproofed = fireproofing.isAllowed(cookieDomain: domain)
        
        if isFireproofed {
            return BrowsingMenuEntry.regular(name: UserText.disablePreservingLogins,
                                             image: UIImage(named: "MenuRemoveFireproof")!,
                                             action: { [weak self] in
                                                self?.disableFireproofingForDomain(domain)
                                             })
        }

        return BrowsingMenuEntry.regular(name: UserText.enablePreservingLogins,
                                         image: UIImage(named: "MenuFireproof")!,
                                         action: { [weak self] in
                                            self?.enableFireproofingForDomain(domain)
                                         })
    }

    private func buildCopyEntry(smallIcon: Bool) -> BrowsingMenuEntry {
        let image = UIImage(resource: smallIcon ? .copy16 : .copy24)
        return BrowsingMenuEntry.regular(name: UserText.actionCopy, image: image, action: { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.isError, let url = strongSelf.webView.url {
                strongSelf.onCopyAction(forUrl: url)
            } else if let text = self?.chromeDelegate?.omniBar.text {
                strongSelf.onCopyAction(for: text)
            }

            Pixel.fire(pixel: .browsingMenuCopy)
            let addressBarBottom = strongSelf.appSettings.currentAddressBarPosition.isBottom
            ActionMessageView.present(message: UserText.actionCopyMessage,
                                      presentationLocation: .withBottomBar(andAddressBarBottom: addressBarBottom))
        })
    }

    private func onNewTabAction() {
        Pixel.fire(pixel: .browsingMenuNewTab)
        delegate?.tabDidRequestNewTab(self)
    }

    private func buildFindInPageEntry(forLink link: Link) -> BrowsingMenuEntry {
        return BrowsingMenuEntry.regular(name: UserText.findInPage, image: UIImage(named: "Find-16")!, action: { [weak self] in
            Pixel.fire(pixel: .browsingMenuFindInPage)
            self?.requestFindInPage()
        })
    }
    
    private func buildBookmarkEntries(for link: Link,
                                      with bookmarksInterface: MenuBookmarksInteracting) -> (bookmark: BrowsingMenuEntry,
                                                                                             favorite: BrowsingMenuEntry) {
        let existingFavorite = bookmarksInterface.favorite(for: link.url)
        let existingBookmark = existingFavorite ?? bookmarksInterface.bookmark(for: link.url)
        
        return (bookmark: buildBookmarkEntry(for: link,
                                             bookmark: existingBookmark,
                                             with: bookmarksInterface),
                favorite: buildFavoriteEntry(for: link,
                                             bookmark: existingFavorite,
                                             with: bookmarksInterface))
    }

    private func buildBookmarkEntry(for link: Link,
                                    bookmark: BookmarkEntity?,
                                    with bookmarksInterface: MenuBookmarksInteracting) -> BrowsingMenuEntry {
        
        if bookmark != nil {
            return BrowsingMenuEntry.regular(name: UserText.actionEditBookmark,
                                             image: UIImage(named: "Bookmark-Solid-16")!,
                                             action: { [weak self] in
                                                self?.performEditBookmarkAction(for: link)
                                             })
        }

        return BrowsingMenuEntry.regular(name: UserText.actionSaveBookmark,
                                         image: UIImage(named: "Bookmark-16")!,
                                         action: { [weak self] in
                                           self?.performSaveBookmarkAction(for: link,
                                                                           with: bookmarksInterface)
                                         })
    }

    private func buildOpenBookmarksEntry() -> BrowsingMenuEntry {
        BrowsingMenuEntry.regular(name: UserText.actionOpenBookmarks,
                                                 image: UIImage(named: "Library-16")!,
                                                 action: { [weak self] in
            self?.onOpenBookmarksAction()
        })
    }

    private func performSaveBookmarkAction(for link: Link,
                                           with bookmarksInterface: MenuBookmarksInteracting) {
        Pixel.fire(pixel: .browsingMenuAddToBookmarks)
        DailyPixel.fire(pixel: .addBookmarkDaily)
        bookmarksInterface.createBookmark(title: link.title ?? "", url: link.url)
        favicons.loadFavicon(forDomain: link.url.host, intoCache: .fireproof, fromCache: .tabs)
        syncService.scheduler.notifyDataChanged()

        ActionMessageView.present(message: UserText.webSaveBookmarkDone,
                                  actionTitle: UserText.actionGenericEdit,
                                  presentationLocation: .withBottomBar(andAddressBarBottom: appSettings.currentAddressBarPosition.isBottom),
                                  onAction: {
            self.performEditBookmarkAction(for: link)
        })
    }

    private func performEditBookmarkAction(for link: Link) {
        Pixel.fire(pixel: .browsingMenuEditBookmark)

        delegate?.tabDidRequestEditBookmark(tab: self)
    }

    private func buildFavoriteEntry(for link: Link,
                                    bookmark: BookmarkEntity?,
                                    with bookmarksInterface: MenuBookmarksInteracting) -> BrowsingMenuEntry {
        if bookmark?.isFavorite(on: .mobile) ?? false {
            let action: () -> Void = { [weak self] in
                Pixel.fire(pixel: .browsingMenuRemoveFromFavorites)
                self?.performRemoveFavoriteAction(for: link, with: bookmarksInterface)
            }

            let entry = BrowsingMenuEntry.regular(name: UserText.actionRemoveFavorite,
                                                  image: UIImage(named: "Favorite-Solid-16")!,
                                                  action: action)
            return entry

        }

        // Capture flow state here as will be reset after menu is shown
        let addToFavoriteFlow = DaxDialogs.shared.isAddFavoriteFlow

        let entry = BrowsingMenuEntry.regular(name: UserText.actionSaveFavorite,
                                              image: UIImage(named: "Favorite-16")!,
                                              action: { [weak self] in
            Pixel.fire(pixel: addToFavoriteFlow ? .browsingMenuAddToFavoritesAddFavoriteFlow : .browsingMenuAddToFavorites)
            DailyPixel.fire(pixel: .addFavoriteDaily)
            self?.performAddFavoriteAction(for: link, with: bookmarksInterface)
        })
        return entry
    }
    
    private func performAddFavoriteAction(for link: Link,
                                          with bookmarksInterface: MenuBookmarksInteracting) {
        bookmarksInterface.createOrToggleFavorite(title: link.title ?? "", url: link.url)
        favicons.loadFavicon(forDomain: link.url.host, intoCache: .fireproof, fromCache: .tabs)
        WidgetCenter.shared.reloadAllTimelines()
        syncService.scheduler.notifyDataChanged()

        ActionMessageView.present(message: UserText.webSaveFavoriteDone,
                                  actionTitle: UserText.actionGenericUndo,
                                  presentationLocation: .withBottomBar(andAddressBarBottom: appSettings.currentAddressBarPosition.isBottom),
                                  onAction: {
            self.performRemoveFavoriteAction(for: link, with: bookmarksInterface)
        })
    }
    
    private func performRemoveFavoriteAction(for link: Link,
                                             with bookmarksInterface: MenuBookmarksInteracting) {
        bookmarksInterface.createOrToggleFavorite(title: link.title ?? "", url: link.url)
        WidgetCenter.shared.reloadAllTimelines()
        syncService.scheduler.notifyDataChanged()

        ActionMessageView.present(message: UserText.webFavoriteRemoved,
                                  actionTitle: UserText.actionGenericUndo,
                                  presentationLocation: .withBottomBar(andAddressBarBottom: appSettings.currentAddressBarPosition.isBottom),
                                  onAction: {
            self.performAddFavoriteAction(for: link, with: bookmarksInterface)
        })
    }
    
    private func buildUseNewDuckAddressEntry(forLink link: Link) -> BrowsingMenuEntry? {
        guard emailManager?.isSignedIn == true else { return nil }
        let title = UserText.emailBrowsingMenuUseNewDuckAddress
        let image = UIImage(named: "Email-16")!

        return BrowsingMenuEntry.regular(name: title, image: image) { [weak self] in
            (self?.parent as? MainViewController)?.newEmailAddress()
        }
    }

    func onShareAction(forLink link: Link, fromView view: UIView) {
        shareLinkWithTemporaryDownload(temporaryDownloadForPreviewedFile, originalLink: link) { [weak self] link in
            guard let self = self else { return }
            var items: [Any] = [link, self.webView.viewPrintFormatter()]

            if let webView = self.webView {
                items.append(webView)
            }

            self.presentShareSheet(withItems: items, fromView: view) { [weak self] activityType, result, _, error in
                if result {
                    Pixel.fire(pixel: .shareSheetResultSuccess)
                } else {
                    Pixel.fire(pixel: .shareSheetResultFail, error: error)
                }

                if let activityType {
                    self?.firePixelForActivityType(activityType)
                }
            }
        }
    }
    
    private func firePixelForActivityType(_ activityType: UIActivity.ActivityType) {
        switch activityType {
        case .copyToPasteboard:
            Pixel.fire(pixel: .shareSheetActivityCopy)
        case .saveBookmarkInDuckDuckGo:
            Pixel.fire(pixel: .shareSheetActivityAddBookmark)
        case .saveFavoriteInDuckDuckGo:
            Pixel.fire(pixel: .shareSheetActivityAddFavorite)
        case .findInPage:
            Pixel.fire(pixel: .shareSheetActivityFindInPage)
        case .print:
            Pixel.fire(pixel: .shareSheetActivityPrint)
        case .addToReadingList:
            Pixel.fire(pixel: .shareSheetActivityAddToReadingList)
        default:
            Pixel.fire(pixel: .shareSheetActivityOther)
        }
    }

    private func shareLinkWithTemporaryDownload(_ temporaryDownload: Download?,
                                                originalLink: Link,
                                                completion: @escaping (Link) -> Void) {
        guard let download = temporaryDownload else {
            completion(originalLink)
            return
        }
        
        if let downloadLink = download.link {
            completion(downloadLink)
            return
        }
        
        AppDependencyProvider.shared.downloadManager.startDownload(download) { error in
            DispatchQueue.main.async {
                if error == nil, let downloadLink = download.link {
                    let fileSize = downloadLink.localFileURL?.fileSize ?? 0
                    let isFileSizeGreaterThan10MB = (fileSize > 10 * 1000 * 1000)
                    Pixel.fire(pixel: .downloadsSharingPredownloadedLocalFile,
                               withAdditionalParameters: [PixelParameters.fileSizeGreaterThan10MB: isFileSizeGreaterThan10MB ? "1" : "0"])
                    completion(downloadLink)
                } else {
                    completion(originalLink)
                }
            }
        }
    }
    
    private func onToggleDesktopSiteAction(forUrl url: URL) {
        Pixel.fire(pixel: .browsingMenuToggleBrowsingMode)
        tabModel.toggleDesktopMode()
        updateContentMode()
        
        if tabModel.isDesktop {
            load(url: url.toDesktopUrl())
        } else {
            reload()
        }
    }
    
    private func onReportBrokenSiteAction() {
        Pixel.fire(pixel: .browsingMenuReportBrokenSite)
        delegate?.tabDidRequestReportBrokenSite(tab: self)
    }
    
    private func onOpenDownloadsAction() {
        Pixel.fire(pixel: .downloadsListOpened,
                   withAdditionalParameters: [PixelParameters.originatedFromMenu: "1"])
        delegate?.tabDidRequestDownloads(tab: self)
    }
    
    private func onOpenAutofillLoginsAction() {
        Pixel.fire(pixel: .browsingMenuAutofill)
        delegate?.tab(self, didRequestAutofillLogins: nil, source: .overflow)
    }
    
    private func onBrowsingSettingsAction() {
        Pixel.fire(pixel: .settingsPresentedFromMenu)
        delegate?.tabDidRequestSettings(tab: self)
    }

    private func onOpenBookmarksAction() {
        delegate?.tabDidRequestBookmarks(tab: self)
    }

    private func openAIChat() {
        delegate?.tabDidRequestAIChat(tab: self)
    }

    private func buildToggleProtectionEntry(forDomain domain: String) -> BrowsingMenuEntry {
        let config = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        let isProtected = !config.isUserUnprotected(domain: domain)
        let title = isProtected ? UserText.actionDisableProtection : UserText.actionEnableProtection
        let image = isProtected ? UIImage(named: "Protections-Blocked-16")! : UIImage(named: "Protections-16")!
    
        return BrowsingMenuEntry.regular(name: title, image: image, action: { [weak self] in
            self?.onToggleProtectionAction(forDomain: domain, isProtected: isProtected)
        })
    }

    private func onToggleProtectionAction(forDomain domain: String, isProtected: Bool) {
        let toggleReportingConfig = ToggleReportingConfiguration(privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager)
        let toggleReportingFeature = ToggleReportingFeature(toggleReportingConfiguration: toggleReportingConfig)
        let toggleReportingManager = ToggleReportingManager(feature: toggleReportingFeature)
        if isProtected && toggleReportingManager.shouldShowToggleReport {
            delegate?.tab(self, didRequestToggleReportWithCompletionHandler: { [weak self] didSendReport in
                self?.togglePrivacyProtection(domain: domain, didSendReport: didSendReport)
            })
        } else {
            togglePrivacyProtection(domain: domain)
        }
        Pixel.fire(pixel: isProtected ? .browsingMenuDisableProtection : .browsingMenuEnableProtection)
        let tdsEtag = AppDependencyProvider.shared.configurationStore.loadEtag(for: .trackerDataSet) ?? ""
        SiteBreakageExperimentMetrics.fireTDSExperimentMetric(metricType: .privacyToggleUsed, etag: tdsEtag) { parameters in
            UniquePixel.fire(pixel: .debugBreakageExperiment, withAdditionalParameters: parameters)
        }
        SiteBreakageExperimentMetrics.fireContentScopeExperimentMetric(metricType: .privacyToggleUsed)
    }

    private func togglePrivacyProtection(domain: String, didSendReport: Bool = false) {
        let config = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        let isProtected = !config.isUserUnprotected(domain: domain)
        if isProtected {
            config.userDisabledProtection(forDomain: domain)
        } else {
            config.userEnabledProtection(forDomain: domain)
        }
        
        let message: String
        if isProtected {
            if didSendReport {
                message = UserText.messageProtectionDisabledAndToggleReportSent.format(arguments: domain)
            } else {
                message = UserText.messageProtectionDisabled.format(arguments: domain)
            }
        } else {
            message = UserText.messageProtectionEnabled.format(arguments: domain)
        }
        
        ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
        
        ActionMessageView.present(message: message, actionTitle: UserText.actionGenericUndo,
                                  presentationLocation: .withBottomBar(andAddressBarBottom: appSettings.currentAddressBarPosition.isBottom),
                                  onAction: { [weak self] in
            self?.togglePrivacyProtection(domain: domain)
        })
    }

}
