//
//  MoreOptionsMenu.swift
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

import Cocoa
import Combine
import Common
import BrowserServicesKit
import PixelKit
import NetworkProtection
import Subscription
import os.log
import Freemium
import DataBrokerProtection_macOS
import DataBrokerProtectionCore
import SwiftUI

protocol OptionsButtonMenuDelegate: AnyObject {

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkAllOpenTabs(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkExportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category)
    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu)
    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedPrint(_ menu: NSMenu)
    func optionsButtonMenuRequestedPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedAppearancePreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedAccessibilityPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu)
    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu)
    func optionsButtonMenuRequestedSubscriptionPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu)
}

final class MoreOptionsMenu: NSMenu, NSMenuDelegate {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private let fireproofDomains: FireproofDomains
    private let passwordManagerCoordinator: PasswordManagerCoordinating
    private let internalUserDecider: InternalUserDecider
    @MainActor
    private lazy var sharingMenu: NSMenu = SharingMenu(title: UserText.shareMenuItem)
    private let subscriptionManager: any SubscriptionAuthV1toV2Bridge
    private let freemiumDBPUserStateManager: FreemiumDBPUserStateManager
    private let freemiumDBPFeature: FreemiumDBPFeature
    private let freemiumDBPPresenter: FreemiumDBPPresenter
    private let appearancePreferences: AppearancePreferences
    private var dockCustomizer: DockCustomization?
    private let defaultBrowserPreferences: DefaultBrowserPreferences
    private let featureFlagger: FeatureFlagger

    private let notificationCenter: NotificationCenter

    private let vpnFeatureGatekeeper: VPNFeatureGatekeeper
    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability
    private let aiChatMenuConfiguration: AIChatMenuVisibilityConfigurable
    private let moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding

    /// The `FreemiumDBPExperimentPixelHandler` instance used to fire pixels
    private let freemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel>

    required init(coder: NSCoder) {
        fatalError("MoreOptionsMenu: Bad initializer")
    }

    @MainActor
    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager = EmailManager(),
         fireproofDomains: FireproofDomains = FireproofDomains.shared,
         passwordManagerCoordinator: PasswordManagerCoordinator,
         vpnFeatureGatekeeper: VPNFeatureGatekeeper,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability(),
         sharingMenu: NSMenu? = nil,
         internalUserDecider: InternalUserDecider,
         subscriptionManager: any SubscriptionAuthV1toV2Bridge,
         freemiumDBPUserStateManager: FreemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp),
         freemiumDBPFeature: FreemiumDBPFeature,
         freemiumDBPPresenter: FreemiumDBPPresenter = DefaultFreemiumDBPPresenter(),
         appearancePreferences: AppearancePreferences = .shared,
         dockCustomizer: DockCustomization? = nil,
         defaultBrowserPreferences: DefaultBrowserPreferences = .shared,
         notificationCenter: NotificationCenter = .default,
         featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger,
         freemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel> = FreemiumDBPExperimentPixelHandler(),
         aiChatMenuConfiguration: AIChatMenuVisibilityConfigurable = AIChatMenuConfiguration(),
         visualStyleManager: VisualStyleManagerProviding = NSApp.delegateTyped.visualStyleManager) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        self.fireproofDomains = fireproofDomains
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.vpnFeatureGatekeeper = vpnFeatureGatekeeper
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.internalUserDecider = internalUserDecider
        self.subscriptionManager = subscriptionManager
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
        self.freemiumDBPFeature = freemiumDBPFeature
        self.freemiumDBPPresenter = freemiumDBPPresenter
        self.appearancePreferences = appearancePreferences
        self.dockCustomizer = dockCustomizer
        self.defaultBrowserPreferences = defaultBrowserPreferences
        self.notificationCenter = notificationCenter
        self.freemiumDBPExperimentPixelHandler = freemiumDBPExperimentPixelHandler
        self.aiChatMenuConfiguration = aiChatMenuConfiguration
        self.featureFlagger = featureFlagger
        self.moreOptionsMenuIconsProvider = visualStyleManager.style.moreOptionsMenuIconsProvider

        super.init(title: "")

        if let sharingMenu {
            self.sharingMenu = sharingMenu
        }
        self.emailManager.requestDelegate = self

        delegate = self

        setupMenuItems()
    }

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "").withImage(.zoomIn)

    @MainActor
    private func setupMenuItems() {
        addUpdateItem()

#if FEEDBACK
        let feedbackString: String = {
            guard internalUserDecider.isInternalUser else {
                return UserText.sendFeedback
            }
            return "\(UserText.sendFeedback) (version: \(AppVersion.shared.versionNumber).\(AppVersion.shared.buildNumber))"
        }()
        let feedbackMenuItem = NSMenuItem(title: feedbackString, action: nil, keyEquivalent: "")
            .withImage(moreOptionsMenuIconsProvider.sendFeedbackIcon)

        feedbackMenuItem.submenu = FeedbackSubMenu(targetting: self,
                                                   tabCollectionViewModel: tabCollectionViewModel,
                                                   subscriptionFeatureAvailability: subscriptionFeatureAvailability,
                                                   authenticationStateProvider: subscriptionManager,
                                                   internalUserDecider: internalUserDecider,
                                                   moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
        addItem(feedbackMenuItem)

#endif // FEEDBACK

#if SPARKLE
        if let dockCustomizer = self.dockCustomizer {
            if dockCustomizer.isAddedToDock == false {
                if dockCustomizer.shouldShowNotification {
                    let addToDockMenuItem = NSMenuItem(action: #selector(addToDock(_:)))
                        .targetting(self)
                    addToDockMenuItem.view = createMenuItemWithFeatureIndicator(
                        title: UserText.addDuckDuckGoToDock,
                        image: moreOptionsMenuIconsProvider.addToDockIcon) {
                            if let target = addToDockMenuItem.target {
                                _ = target.perform(addToDockMenuItem.action, with: addToDockMenuItem)
                            }
                            self.cancelTracking()
                        }
                    addItem(addToDockMenuItem)
                } else {
                    let addToDockMenuItem = NSMenuItem(title: UserText.addDuckDuckGoToDock, action: #selector(addToDock(_:)))
                        .targetting(self)
                        .withImage(moreOptionsMenuIconsProvider.addToDockIcon)
                    addItem(addToDockMenuItem)
                }
            }
        }
#endif
        if !defaultBrowserPreferences.isDefault {
            let setAsDefaultMenuItem = NSMenuItem(title: UserText.setAsDefaultBrowser, action: #selector(setAsDefault(_:)))
                .targetting(self)
                .withImage(moreOptionsMenuIconsProvider.setAsDefaultBrowserIcon)
            addItem(setAsDefaultMenuItem)
        }

        addItem(NSMenuItem.separator())

        addWindowItems()

        zoomMenuItem.submenu = ZoomSubMenu(targetting: self,
                                           tabCollectionViewModel: tabCollectionViewModel,
                                           moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
        addItem(zoomMenuItem)

        addItem(NSMenuItem.separator())

        addUtilityItems()

        addItem(withTitle: UserText.emailOptionsMenuItem, action: nil, keyEquivalent: "")
            .withImage(moreOptionsMenuIconsProvider.emailProtectionIcon)
            .withSubmenu(EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel,
                                                   emailManager: emailManager,
                                                   moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider))

        addItem(NSMenuItem.separator())

        addSubscriptionAndFreemiumDBPItems()

        addPageItems()

        let helpItem = NSMenuItem(title: UserText.mainMenuHelp, action: nil, keyEquivalent: "")
            .withImage(moreOptionsMenuIconsProvider.helpIcon)
        helpItem.submenu = HelpSubMenu(targetting: self)
        addItem(helpItem)

        let preferencesItem = NSMenuItem(title: UserText.settings, action: #selector(openPreferences(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.settingsIcon)
        addItem(preferencesItem)
    }

    private func createMenuItemWithFeatureIndicator(title: String, image: NSImage, onTap: @escaping () -> Void) -> NSView {
        let menuItem = MenuItemWithNotificationDot(leftImage: image, title: title, onTapMenuItem: onTap)

        let hostingView = NSHostingView(rootView: menuItem)
        hostingView.frame = NSRect(x: 0, y: 0, width: size.width, height: 22)
        hostingView.autoresizingMask = [.width, .height]

        return hostingView
    }

    @objc func openDataBrokerProtection(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDataBrokerProtection(self)
    }

    @objc func showNetworkProtectionStatus(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedNetworkProtectionPopover(self)
    }

    @MainActor
    @objc func addToDock(_ sender: NSMenuItem) {
        PixelKit.fire(GeneralPixel.userAddedToDockFromMoreOptionsMenu)
        dockCustomizer?.addToDock()
    }

    @MainActor
    @objc func setAsDefault(_ sender: NSMenuItem) {
        PixelKit.fire(GeneralPixel.defaultRequestedFromMoreOptionsMenu)
        defaultBrowserPreferences.becomeDefault()
    }

    @MainActor
    @objc func newTab(_ sender: NSMenuItem) {
        tabCollectionViewModel.appendNewTab()
    }

    @MainActor
    @objc func newWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow()
    }

    @MainActor
    @objc func newBurnerWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow(burnerMode: BurnerMode(isBurner: true))
    }

    @MainActor
    @objc func newAiChat(_ sender: NSMenuItem) {
        NSApp.delegateTyped.aiChatTabOpener.openAIChatTab()
        PixelKit.fire(AIChatPixel.aichatApplicationMenuAppClicked, frequency: .dailyAndCount, includeAppVersionParameter: true)
    }

    @MainActor
    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("MainViewController: No tab view model selected")
            return
        }

        selectedTabViewModel.tab.requestFireproofToggle()
    }

    @objc func bookmarkPage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkThisPage(sender)
    }

    @objc func bookmarkAllOpenTabs(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkAllOpenTabs(sender)
    }

    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }

    @objc func openBookmarksManagementInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkManagementInterface(self)
    }

    @objc func openBookmarkImportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkImportInterface(self)
    }

    @objc func openBookmarkExportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkExportInterface(self)
    }

    @objc func openDownloads(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDownloadsPopover(self)
    }

    @objc func openAutofillWithAllItems(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .allItems)
    }

    @objc func openAutofillWithLogins(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .logins)
    }

    @objc func openExternalPasswordManager(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedOpenExternalPasswordManager(self)
    }

    @objc func openAutofillWithIdentities(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .identities)
    }

    @objc func openAutofillWithCreditCards(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .cards)
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPreferences(self)
    }

    @objc func openAppearancePreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedAppearancePreferences(self)
    }

    @objc func openAccessibilityPreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedAccessibilityPreferences(self)
    }

    @objc func openSubscriptionPurchasePage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedSubscriptionPurchasePage(self)
    }

    @objc func openSubscriptionSettings(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedSubscriptionPreferences(self)
    }

    @objc func openIdentityTheftRestoration(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedIdentityTheftRestoration(self)
    }

    @MainActor
    @objc func openFreemiumDBP(_ sender: NSMenuItem) {

        if freemiumDBPUserStateManager.didPostFirstProfileSavedNotification {
            freemiumDBPExperimentPixelHandler.fire(FreemiumDBPExperimentPixel.overFlowResults)
        } else {
            freemiumDBPExperimentPixelHandler.fire(FreemiumDBPExperimentPixel.overFlowScan)
        }

        freemiumDBPPresenter.showFreemiumDBPAndSetActivated(windowControllerManager: WindowControllersManager.shared)
        notificationCenter.post(name: .freemiumDBPEntryPointActivated, object: nil)
    }

    @MainActor
    @objc func findInPage(_ sender: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.showFindInPage()
    }

    @objc func doPrint(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPrint(self)
    }

    private func addUpdateItem() {
#if SPARKLE
        guard AppVersion.runType != .uiTests,
              let updateController = Application.appDelegate.updateController,
              let update = updateController.latestUpdate else {
            return
        }

        // Log edge cases where menu item appears but doesn't function
        // To be removed in a future version
        if !update.isInstalled, updateController.updateProgress.isDone {
            updateController.log()
        }

        guard updateController.hasPendingUpdate else {
            return
        }

        if featureFlagger.isFeatureOn(.updatesWontAutomaticallyRestartApp) {
            addItem(UpdateMenuItemFactory.menuItem(for: updateController))
        } else {
            addItem(UpdateMenuItemFactory.menuItem(for: update))
        }

        addItem(NSMenuItem.separator())
#endif
    }

    private func addWindowItems() {
        // New Tab
        addItem(withTitle: UserText.plusButtonNewTabMenuItem, action: #selector(newTab(_:)), keyEquivalent: "t")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.newTabIcon)

        // New Window
        addItem(withTitle: UserText.newWindowMenuItem, action: #selector(newWindow(_:)), keyEquivalent: "n")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.newWindowIcon)

        // New Burner Window
        let burnerWindowItem = NSMenuItem(title: UserText.newBurnerWindowMenuItem,
                                          action: #selector(newBurnerWindow(_:)),
                                          target: self)
        burnerWindowItem.keyEquivalent = "n"
        burnerWindowItem.keyEquivalentModifierMask = [.command, .shift]
        burnerWindowItem.image = moreOptionsMenuIconsProvider.newFireWindowIcon
        addItem(burnerWindowItem)

        // New AI Chat
        if aiChatMenuConfiguration.shouldDisplayApplicationMenuShortcut {
            let aiChatItem = NSMenuItem(title: UserText.newAIChatMenuItem,
                                        action: #selector(newAiChat(_:)),
                                        target: self)
            aiChatItem.keyEquivalent = "n"
            aiChatItem.keyEquivalentModifierMask = [.command, .option]
            aiChatItem.image = moreOptionsMenuIconsProvider.newAIChatIcon
            addItem(aiChatItem)
        }

        addItem(NSMenuItem.separator())
    }

    @MainActor
    private func addUtilityItems() {
        let bookmarksSubMenu = BookmarksSubMenu(targetting: self,
                                                tabCollectionViewModel: tabCollectionViewModel,
                                                moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)

        addItem(withTitle: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.bookmarksIcon)
            .withSubmenu(bookmarksSubMenu)
            .withAccessibilityIdentifier("MoreOptionsMenu.openBookmarks")
        addItem(withTitle: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.downloadsIcon)

        if featureFlagger.isFeatureOn(.historyView) {
            addItem(withTitle: UserText.mainMenuHistory, action: nil, keyEquivalent: "")
                .withImage(moreOptionsMenuIconsProvider.historyIcon)
                .withSubmenu(HistoryMenu(location: .moreOptionsMenu))
        }

        let loginsSubMenu = LoginsSubMenu(targetting: self,
                                          passwordManagerCoordinator: passwordManagerCoordinator,
                                          moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)

        addItem(withTitle: UserText.passwordManagementTitle, action: #selector(openAutofillWithAllItems), keyEquivalent: "")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.passwordsIcon)
            .withSubmenu(loginsSubMenu)
            .withAccessibilityIdentifier("MoreOptionsMenu.autofill")

        addItem(NSMenuItem.separator())
    }

    @MainActor
    private func addSubscriptionAndFreemiumDBPItems() {
        addSubscriptionItems()
        addFreemiumDBPItem()

        addItem(NSMenuItem.separator())
    }

    @MainActor
    private func addSubscriptionItems() {
        func shouldHideDueToNoProduct() -> Bool {
            let platform = subscriptionManager.currentEnvironment.purchasePlatform
            return platform == .appStore && subscriptionManager.canPurchase == false
        }

        let privacyProItem = NSMenuItem(title: UserText.subscriptionOptionsMenuItem)
            .withImage(moreOptionsMenuIconsProvider.privacyProIcon)

        if !subscriptionManager.isUserAuthenticated {
            privacyProItem.target = self
            privacyProItem.action = #selector(openSubscriptionPurchasePage(_:))

            // Do not add for App Store when purchase not available in the region
            if !shouldHideDueToNoProduct() {
                addItem(privacyProItem)
            }
        } else {
            privacyProItem.submenu = SubscriptionSubMenu(targeting: self,
                                                         subscriptionFeatureAvailability: DefaultSubscriptionFeatureAvailability(),
                                                         subscriptionManager: subscriptionManager,
                                                         moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
            addItem(privacyProItem)
        }
    }

    @MainActor
    private func addFreemiumDBPItem() {
        guard freemiumDBPFeature.isAvailable else { return }

        let freemiumDBPItem = NSMenuItem(title: UserText.freemiumDBPOptionsMenuItem)
            .withImage(moreOptionsMenuIconsProvider.personalInformationRemovalIcon)

        freemiumDBPItem.target = self
        freemiumDBPItem.action = #selector(openFreemiumDBP(_:))

        addItem(freemiumDBPItem)
    }

    @MainActor
    private func addPageItems() {
        guard let tabViewModel = tabCollectionViewModel.selectedTabViewModel,
              let url = tabViewModel.tab.content.userEditableUrl else { return }
        let oldItemsCount = items.count

        if url.canFireproof, let host = url.host {
            let isFireproof = fireproofDomains.isFireproof(fireproofDomain: host)
            let title = isFireproof ? UserText.removeFireproofing : UserText.fireproofSite
            let image: NSImage = isFireproof ? moreOptionsMenuIconsProvider.removeFireproofIcon : moreOptionsMenuIconsProvider.fireproofSiteIcon

            addItem(withTitle: title, action: #selector(toggleFireproofing(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(image)
        } else {
            addItem(withTitle: UserText.fireproofSite, action: nil, keyEquivalent: "")
                .withImage(moreOptionsMenuIconsProvider.fireproofSiteIcon)
        }

        addItem(withTitle: UserText.findInPageMenuItem, action: tabViewModel.canFindInPage ? #selector(findInPage(_:)) : nil, keyEquivalent: "f")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.findInPageIcon)
            .withAccessibilityIdentifier("MoreOptionsMenu.findInPage")

        let shareItem = addItem(withTitle: UserText.shareMenuItem, action: nil, keyEquivalent: "")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.shareIcon)
            .withSubmenu(sharingMenu)
        shareItem.isEnabled = tabViewModel.canShare

        addItem(withTitle: UserText.printMenuItem, action: tabViewModel.canPrint ? #selector(doPrint(_:)) : nil, keyEquivalent: "")
            .targetting(self)
            .withImage(moreOptionsMenuIconsProvider.printIcon)

        if items.count > oldItemsCount {
            addItem(NSMenuItem.separator())
        }
    }

    private func makeNetworkProtectionItem() -> NSMenuItem {
        let networkProtectionItem = NSMenuItem(title: "", action: #selector(showNetworkProtectionStatus(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.image(for: .vpnIcon))

        networkProtectionItem.title = UserText.networkProtection

        return networkProtectionItem
    }

    func menuWillOpen(_ menu: NSMenu) {
#if SPARKLE
        guard let updateController = Application.appDelegate.updateController else { return }
        if updateController.hasPendingUpdate && updateController.needsNotificationDot {
            updateController.needsNotificationDot = false
        }
#endif
    }

    func menuDidClose(_ menu: NSMenu) {
        dockCustomizer?.didCloseMoreOptionsMenu()
    }
}

final class EmailOptionsButtonSubMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private var emailProtectionDidChangeCancellable: AnyCancellable?

    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: UserText.emailOptionsMenuItem)

        updateMenuItems(moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)

        emailProtectionDidChangeCancellable = Publishers
            .Merge(
                NotificationCenter.default.publisher(for: .emailDidSignIn),
                NotificationCenter.default.publisher(for: .emailDidSignOut)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems(moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
            }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        removeAllItems()
        if emailManager.isSignedIn {
            addItem(withTitle: UserText.emailOptionsMenuCreateAddressSubItem, action: #selector(createAddressAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(moreOptionsMenuIconsProvider.emailGenerateAddressIcon)

            addItem(withTitle: UserText.emailOptionsMenuManageAccountSubItem, action: #selector(manageAccountAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(moreOptionsMenuIconsProvider.emailManageAccount)

            addItem(.separator())

            addItem(withTitle: UserText.emailOptionsMenuTurnOffSubItem, action: #selector(turnOffEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(moreOptionsMenuIconsProvider.emailProtectionTurnOffIcon)

        } else {
            addItem(withTitle: UserText.emailOptionsMenuTurnOnSubItem, action: #selector(turnOnEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(moreOptionsMenuIconsProvider.emailProtectionTurnOnIcon)

        }
    }

    @MainActor
    @objc func manageAccountAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionAccountLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }

    @objc func createAddressAction(_ sender: NSMenuItem) {
        assert(emailManager.requestDelegate != nil, "No requestDelegate on emailManager")

        emailManager.getAliasIfNeededAndConsume { [weak self] alias, error in
            guard let self = self, let alias = alias else {
                assertionFailure(error?.localizedDescription ?? "Unexpected email error")
                return
            }

            let address = self.emailManager.emailAddressFor(alias)
            let pixelParameters = self.emailManager.emailPixelParameters
            self.emailManager.updateLastUseDate()

            PixelKit.fire(NonStandardEvent(NonStandardPixel.emailUserCreatedAlias), withAdditionalParameters: pixelParameters)

            NSPasteboard.general.copy(address)
            NotificationCenter.default.post(name: NSNotification.Name.privateEmailCopiedToClipboard, object: nil)
        }
    }

    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        let alert = NSAlert.disableEmailProtection()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            try? emailManager.signOut()
        }
    }

    @MainActor
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }
}

final class FeedbackSubMenu: NSMenu {
    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability
    private let authenticationStateProvider: any SubscriptionAuthenticationStateProvider
    private let internalUserDecider: InternalUserDecider

    init(targetting target: AnyObject,
         tabCollectionViewModel: TabCollectionViewModel,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability,
         authenticationStateProvider: any SubscriptionAuthenticationStateProvider,
         internalUserDecider: InternalUserDecider,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.authenticationStateProvider = authenticationStateProvider
        self.internalUserDecider = internalUserDecider
        super.init(title: UserText.sendFeedback)
        updateMenuItems(with: tabCollectionViewModel, targetting: target, moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel,
                                 targetting target: AnyObject,
                                 moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        removeAllItems()

        let browserFeedbackItem = NSMenuItem(title: UserText.browserFeedback,
                                             action: #selector(AppDelegate.openFeedback(_:)),
                                             keyEquivalent: "")
            .withImage(moreOptionsMenuIconsProvider.browserFeedbackIcon)
        addItem(browserFeedbackItem)

        let reportBrokenSiteItem = NSMenuItem(title: UserText.reportBrokenSite,
                                              action: #selector(AppDelegate.openReportBrokenSite(_:)),
                                              keyEquivalent: "")
            .withImage(moreOptionsMenuIconsProvider.reportBrokenSiteIcon)
        addItem(reportBrokenSiteItem)

        if authenticationStateProvider.isUserAuthenticated {
            addItem(.separator())

            let sendPProFeedbackItem = NSMenuItem(title: UserText.sendPProFeedback,
                                                  action: #selector(AppDelegate.openPProFeedback(_:)),
                                                  keyEquivalent: "")
                .withImage(moreOptionsMenuIconsProvider.sendPrivacyProFeedbackIcon)
            addItem(sendPProFeedbackItem)
        }

        if internalUserDecider.isInternalUser {
            addItem(.separator())
            addItem(withTitle: "Copy Version", action: #selector(AppDelegate.copyVersion(_:)), keyEquivalent: "")
        }
    }
}

final class ZoomSubMenu: NSMenu {

    @MainActor
    init(targetting target: AnyObject,
         tabCollectionViewModel: TabCollectionViewModel,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        super.init(title: UserText.zoom)

        updateMenuItems(with: tabCollectionViewModel,
                        targetting: target,
                        moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, targetting target: AnyObject, moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        removeAllItems()

        let fullScreenItem = (NSApp.mainMenuTyped.toggleFullscreenMenuItem.copy() as? NSMenuItem)!
            .withImage(moreOptionsMenuIconsProvider.enterFullscreenIcon)
        addItem(fullScreenItem)

        addItem(.separator())

        let zoomInItem = (NSApp.mainMenuTyped.zoomInMenuItem.copy() as? NSMenuItem)!
            .withImage(moreOptionsMenuIconsProvider.zoomInIcon)
        addItem(zoomInItem)

        let zoomOutItem = (NSApp.mainMenuTyped.zoomOutMenuItem.copy() as? NSMenuItem)!
            .withImage(moreOptionsMenuIconsProvider.zoomOutIcon)
        addItem(zoomOutItem)

        let actualSizeItem = (NSApp.mainMenuTyped.actualSizeMenuItem.copy() as? NSMenuItem)!
            .withImage(NSImage()) // add left padding for the Actual Size item
        addItem(actualSizeItem)

        addItem(.separator())

        let globalZoomSettingItem = NSMenuItem(title: UserText.defaultZoomPageMoreOptionsItem,
                                               action: #selector(MoreOptionsMenu.openAccessibilityPreferences(_:)),
                                               target: target)
            .withImage(moreOptionsMenuIconsProvider.changeDefaultZoomIcon)
        addItem(globalZoomSettingItem)
    }
}

final class BookmarksSubMenu: NSMenu {

    @MainActor
    init(targetting target: AnyObject,
         tabCollectionViewModel: TabCollectionViewModel,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        super.init(title: UserText.passwordManagementTitle)
        self.autoenablesItems = false
        addMenuItems(with: tabCollectionViewModel,
                     target: target,
                     moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func addMenuItems(with tabCollectionViewModel: TabCollectionViewModel,
                              target: AnyObject,
                              moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        let bookmarkPageItem = addItem(withTitle: UserText.bookmarkThisPage, action: #selector(MoreOptionsMenu.bookmarkPage(_:)), keyEquivalent: "d")
            .withModifierMask([.command])
            .targetting(target)
            .withAccessibilityIdentifier("MoreOptionsMenu.bookmarkPage")

        bookmarkPageItem.isEnabled = tabCollectionViewModel.selectedTabViewModel?.canBeBookmarked == true

        let bookmarkAllTabsItem = addItem(withTitle: UserText.bookmarkAllTabs, action: #selector(MoreOptionsMenu.bookmarkAllOpenTabs(_:)), keyEquivalent: "d")
            .withModifierMask([.command, .shift])
            .targetting(target)

        bookmarkAllTabsItem.isEnabled = tabCollectionViewModel.canBookmarkAllOpenTabs()

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.bookmarksShowToolbarPanel, action: #selector(MoreOptionsMenu.openBookmarks(_:)), keyEquivalent: "")
            .targetting(target)

        BookmarksBarMenuFactory.addToMenu(self)

        addItem(withTitle: UserText.bookmarksManageBookmarks, action: #selector(MoreOptionsMenu.openBookmarksManagementInterface), keyEquivalent: "b")
            .withModifierMask([.command, .option])
            .targetting(target)

        addItem(NSMenuItem.separator())

        if let favorites = LocalBookmarkManager.shared.list?.favoriteBookmarks {
            let favoriteViewModels = favorites.compactMap(BookmarkViewModel.init(entity:))
            let potentialItems = bookmarkMenuItems(from: favoriteViewModels)

            let favoritesItem = addItem(withTitle: UserText.favorites, action: nil, keyEquivalent: "")
            favoritesItem.submenu = NSMenu().buildItems {
                NSMenuItem(title: UserText.mainMenuHistoryFavoriteThisPage, action: #selector(MainViewController.favoriteThisPage), keyEquivalent: "")
                    .withImage(moreOptionsMenuIconsProvider.favoritesIcon)
                NSMenuItem.separator()
                potentialItems
            }
            favoritesItem.image = moreOptionsMenuIconsProvider.favoritesIcon

            addItem(NSMenuItem.separator())
        }

        let bookmarkManager = LocalBookmarkManager.shared
        guard let entities = bookmarkManager.list?.topLevelEntities else {
            return
        }

        let bookmarkViewModels = entities.compactMap(BookmarkViewModel.init(entity:))
        let menuItems = bookmarkMenuItems(from: bookmarkViewModels, topLevel: true)

        self.items.append(contentsOf: menuItems)

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.importBookmarks, action: #selector(MoreOptionsMenu.openBookmarkImportInterface(_:)), keyEquivalent: "")
            .targetting(target)

        let exportBookmarItem = NSMenuItem(title: UserText.exportBookmarks, action: #selector(MoreOptionsMenu.openBookmarkExportInterface(_:)), keyEquivalent: "").targetting(target)
        exportBookmarItem.isEnabled = bookmarkManager.list?.totalBookmarks != 0
        addItem(exportBookmarItem)

    }

    @MainActor
    private func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
        var menuItems = [NSMenuItem]()

        if !topLevel {
            let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
            if showOpenInTabsItem {
                menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
                menuItems.append(.separator())
            }
        }

        for viewModel in bookmarkViewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

            if let folder = viewModel.entity as? BookmarkFolder {
                let subMenu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                subMenu.items = childMenuItems

                if !subMenu.items.isEmpty {
                    menuItem.submenu = subMenu
                }
            }

            menuItems.append(menuItem)
        }

        return menuItems
    }

}

final class LoginsSubMenu: NSMenu {
    let passwordManagerCoordinator: PasswordManagerCoordinating

    init(targetting target: AnyObject,
         passwordManagerCoordinator: PasswordManagerCoordinating,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        self.passwordManagerCoordinator = passwordManagerCoordinator
        super.init(title: UserText.passwordManagementTitle)
        updateMenuItems(with: target, moreOptionsMenuIconsProvider: moreOptionsMenuIconsProvider)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with target: AnyObject,
                                 moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {
        addItem(withTitle: UserText.passwordManagementAllItems, action: #selector(MoreOptionsMenu.openAutofillWithAllItems), keyEquivalent: "")
            .targetting(target)
            .withAccessibilityIdentifier("LoginsSubMenu.allItems")

        addItem(NSMenuItem.separator())

        let autofillSelector: Selector
        let autofillTitle: String

        if passwordManagerCoordinator.isEnabled {
            autofillSelector = #selector(MoreOptionsMenu.openExternalPasswordManager)
            autofillTitle = "\(UserText.passwordManagementLogins) (\(UserText.openIn(value: passwordManagerCoordinator.displayName)))"
        } else {
            autofillSelector = #selector(MoreOptionsMenu.openAutofillWithLogins)
            autofillTitle = UserText.passwordManagementLogins
        }

        addItem(withTitle: autofillTitle, action: autofillSelector, keyEquivalent: "")
            .targetting(target)
            .withImage(moreOptionsMenuIconsProvider.passwordsSubMenuIcon)

        addItem(withTitle: UserText.passwordManagementIdentities, action: #selector(MoreOptionsMenu.openAutofillWithIdentities), keyEquivalent: "")
            .targetting(target)
            .withImage(moreOptionsMenuIconsProvider.identitiesIcon)

        addItem(withTitle: UserText.passwordManagementCreditCards, action: #selector(MoreOptionsMenu.openAutofillWithCreditCards), keyEquivalent: "")
            .targetting(target)
            .withImage(moreOptionsMenuIconsProvider.creditCardsIcon)
    }

}

final class HelpSubMenu: NSMenu {

    @MainActor
    init(targetting target: AnyObject) {
        super.init(title: UserText.mainMenuHelp)

        updateMenuItems(targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func updateMenuItems(targetting target: AnyObject) {
        removeAllItems()

        let about = (NSApp.mainMenuTyped.aboutMenuItem.copy() as? NSMenuItem)!
        addItem(about)
#if SPARKLE
        let releaseNotes = (NSApp.mainMenuTyped.releaseNotesMenuItem.copy() as? NSMenuItem)!
        addItem(releaseNotes)

        let whatIsNew = (NSApp.mainMenuTyped.whatIsNewMenuItem.copy() as? NSMenuItem)!
        addItem(whatIsNew)
#endif

#if FEEDBACK
        let feedback = (NSApp.mainMenuTyped.sendFeedbackMenuItem.copy() as? NSMenuItem)!
        addItem(feedback)
#endif
    }
}

final class SubscriptionSubMenu: NSMenu, NSMenuDelegate {

    var subscriptionFeatureAvailability: SubscriptionFeatureAvailability
    var subscriptionManager: any SubscriptionAuthV1toV2Bridge

    var networkProtectionItem: NSMenuItem!
    var dataBrokerProtectionItem: NSMenuItem!
    var identityTheftRestorationItem: NSMenuItem!
    var subscriptionSettingsItem: NSMenuItem!

    private let moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding

    init(targeting target: AnyObject,
         subscriptionFeatureAvailability: SubscriptionFeatureAvailability,
         subscriptionManager: any SubscriptionAuthV1toV2Bridge,
         moreOptionsMenuIconsProvider: MoreOptionsMenuIconsProviding) {

        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
        self.subscriptionManager = subscriptionManager
        self.moreOptionsMenuIconsProvider = moreOptionsMenuIconsProvider

        super.init(title: "")

        self.networkProtectionItem = makeNetworkProtectionItem(target: target)
        self.dataBrokerProtectionItem = makeDataBrokerProtectionItem(target: target)
        self.identityTheftRestorationItem = makeIdentityTheftRestorationItem(target: target)
        self.subscriptionSettingsItem = makeSubscriptionSettingsItem(target: target)

        delegate = self

        Task {
            await addMenuItems()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addMenuItems() async {
        let features = await subscriptionManager.currentSubscriptionFeatures()

        if features.contains(.networkProtection) {
            addItem(networkProtectionItem)
        }
        if features.contains(.dataBrokerProtection) {
            addItem(dataBrokerProtectionItem)
        }
        if features.contains(.identityTheftRestoration) || features.contains(.identityTheftRestorationGlobal) {
            addItem(identityTheftRestorationItem)
        }
        addItem(NSMenuItem.separator())
        addItem(subscriptionSettingsItem)
    }

    private func makeNetworkProtectionItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.networkProtection,
                   action: #selector(MoreOptionsMenu.showNetworkProtectionStatus(_:)),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(moreOptionsMenuIconsProvider.vpnIcon)
    }

    private func makeDataBrokerProtectionItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.dataBrokerProtectionOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openDataBrokerProtection),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(moreOptionsMenuIconsProvider.personalInformationRemovalIcon)
    }

    private func makeIdentityTheftRestorationItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.identityTheftRestorationOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openIdentityTheftRestoration),
                   keyEquivalent: "")
        .targetting(target)
        .withImage(moreOptionsMenuIconsProvider.identityTheftRestorationIcon)
    }

    private func makeSubscriptionSettingsItem(target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.subscriptionSettingsOptionsMenuItem,
                   action: #selector(MoreOptionsMenu.openSubscriptionSettings),
                   keyEquivalent: "")
        .targetting(target)
    }

    private func refreshAvailabilityBasedOnEntitlements() {
        guard subscriptionManager.isUserAuthenticated else { return }

        @Sendable func hasEntitlement(for productName: Entitlement.ProductName) async -> Bool {
            (try? await subscriptionManager.isEnabled(feature: productName)) ?? false
        }

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            let isNetworkProtectionItemEnabled = await hasEntitlement(for: .networkProtection)
            let isDataBrokerProtectionItemEnabled = await hasEntitlement(for: .dataBrokerProtection)

            let hasIdentityTheftRestoration = await hasEntitlement(for: .identityTheftRestoration)
            let hasIdentityTheftRestorationGlobal = await hasEntitlement(for: .identityTheftRestorationGlobal)
            let isIdentityTheftRestorationItemEnabled = hasIdentityTheftRestoration || hasIdentityTheftRestorationGlobal

            Task { @MainActor in
                self.networkProtectionItem.isEnabled = isNetworkProtectionItemEnabled
                self.dataBrokerProtectionItem.isEnabled = isDataBrokerProtectionItemEnabled
                self.identityTheftRestorationItem.isEnabled = isIdentityTheftRestorationItemEnabled
            }
        }
    }

    public func menuWillOpen(_ menu: NSMenu) {
        refreshAvailabilityBasedOnEntitlements()
    }

}

extension MoreOptionsMenu: EmailManagerRequestDelegate {}
