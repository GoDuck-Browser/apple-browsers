//
//  MoreOptionsMenuIconsProviding.swift
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

protocol MoreOptionsMenuIconsProviding {
    var sendFeedbackIcon: NSImage { get }
    var addToDockIcon: NSImage { get }
    var setAsDefaultBrowserIcon: NSImage { get }
    var newTabIcon: NSImage { get }
    var newWindowIcon: NSImage { get }
    var newFireWindowIcon: NSImage { get }
    var newAIChatIcon: NSImage { get }
    var zoomIcon: NSImage { get }
    var zoomInIcon: NSImage { get }
    var zoomOutIcon: NSImage { get }
    var enterFullscreenIcon: NSImage { get }
    var changeDefaultZoomIcon: NSImage { get }
    var bookmarksIcon: NSImage { get }
    var downloadsIcon: NSImage { get }
    var historyIcon: NSImage { get }
    var passwordsIcon: NSImage { get }
    var syncIcon: NSImage { get }
    var emailProtectionIcon: NSImage { get }
    var privacyProIcon: NSImage { get }
    var fireproofSiteIcon: NSImage { get }
    var removeFireproofIcon: NSImage { get }
    var findInPageIcon: NSImage { get }
    var shareIcon: NSImage { get }
    var printIcon: NSImage { get }
    var helpIcon: NSImage { get }
    var settingsIcon: NSImage { get }

    /// Send Feedback Sub-Menu
    var browserFeedbackIcon: NSImage { get }
    var reportBrokenSiteIcon: NSImage { get }
    var sendPrivacyProFeedbackIcon: NSImage { get }

    /// Password & Autofill Sub-Menu
    var passwordsSubMenuIcon: NSImage { get }
    var identitiesIcon: NSImage { get }
    var creditCardsIcon: NSImage { get }

    /// PrivacyPro Sub-Menu
    var vpnIcon: NSImage { get }
    var personalInformationRemovalIcon: NSImage { get }
    var identityTheftRestorationIcon: NSImage { get }

    /// Email Protection Sub-Menu
    var emailGenerateAddressIcon: NSImage { get }
    var emailManageAccount: NSImage { get }
    var emailProtectionTurnOffIcon: NSImage { get }
    var emailProtectionTurnOnIcon: NSImage { get }

    /// Bookmarks Sub-Menu
    var favoritesIcon: NSImage { get }
}

final class LegacyMoreOptionsMenuIcons: MoreOptionsMenuIconsProviding {
    let sendFeedbackIcon: NSImage = .sendFeedback
    let addToDockIcon: NSImage = .addToDockMenuItem
    let setAsDefaultBrowserIcon: NSImage = .defaultBrowserMenuItem
    let newTabIcon: NSImage = .add
    let newWindowIcon: NSImage = .newWindow
    let newFireWindowIcon: NSImage = .newBurnerWindow
    let newAIChatIcon: NSImage = .aiChat
    let zoomIcon: NSImage = .zoomIn
    let zoomInIcon: NSImage = .zoomIn
    let zoomOutIcon: NSImage = .zoomOut
    let enterFullscreenIcon: NSImage = .zoomFullScreen
    let changeDefaultZoomIcon: NSImage = .zoomChangeDefault
    let bookmarksIcon: NSImage = .bookmarks
    let downloadsIcon: NSImage = .downloads
    let historyIcon: NSImage = .history
    let passwordsIcon: NSImage = .passwordManagement
    let syncIcon: NSImage = .syncMenuNew
    let emailProtectionIcon: NSImage = .optionsButtonMenuEmail
    let privacyProIcon: NSImage = .subscriptionIcon
    let fireproofSiteIcon: NSImage = .fireproof
    let removeFireproofIcon: NSImage = .burn
    let findInPageIcon: NSImage = .findSearch
    let shareIcon: NSImage = .share
    let printIcon: NSImage = .print
    let helpIcon: NSImage = .helpMenuItemIcon
    let settingsIcon: NSImage = .preferences
    let browserFeedbackIcon: NSImage = .browserFeedback
    let reportBrokenSiteIcon: NSImage = .siteBreakage
    let sendPrivacyProFeedbackIcon: NSImage = .pProFeedback
    let passwordsSubMenuIcon: NSImage = .loginGlyph
    let identitiesIcon: NSImage = .identityGlyph
    let creditCardsIcon: NSImage = .creditCardGlyph
    let vpnIcon: NSImage = .image(for: .vpnIcon) ?? .vpnMenuNew
    let personalInformationRemovalIcon: NSImage = .dbpIcon
    let identityTheftRestorationIcon: NSImage = .itrIcon
    let emailGenerateAddressIcon: NSImage = .optionsButtonMenuEmailGenerateAddress
    let emailManageAccount: NSImage = .identity16
    let emailProtectionTurnOffIcon: NSImage = .emailDisabled16
    let emailProtectionTurnOnIcon: NSImage = .optionsButtonMenuEmail
    let favoritesIcon: NSImage = .favorite
}

final class NewMoreOptionsMenuIcons: MoreOptionsMenuIconsProviding {
    let sendFeedbackIcon: NSImage = .sendFeedbackMenuNew
    let addToDockIcon: NSImage = .addToDockMenuNew
    let setAsDefaultBrowserIcon: NSImage = .setAsDefaultMenuNew
    let newTabIcon: NSImage = .newTabMenuNew
    let newWindowIcon: NSImage = .newWindowMenuNew
    let newFireWindowIcon: NSImage = .newFireWindowMenuNew
    let newAIChatIcon: NSImage = .newAiChatMenuNew
    let zoomIcon: NSImage = .zoomInMenuNew
    let zoomInIcon: NSImage = .zoomInMenuNew
    let zoomOutIcon: NSImage = .zoomOutMenuNew
    let enterFullscreenIcon: NSImage = .enterFullScreenMenuNew
    let changeDefaultZoomIcon: NSImage = .changeDefaultPageZoomNew
    let bookmarksIcon: NSImage = .bookmarsMenuNew
    let downloadsIcon: NSImage = .downloadsMenuNew
    let historyIcon: NSImage = .historyMenuNew
    let passwordsIcon: NSImage = .passwordMenuNew
    let syncIcon: NSImage = .syncMenuNew
    let emailProtectionIcon: NSImage = .emailProtectionMenuNew
    let privacyProIcon: NSImage = .privacyProMenuNew
    let fireproofSiteIcon: NSImage = .fireproofSiteMenuNew
    let removeFireproofIcon: NSImage = .fireNew
    let findInPageIcon: NSImage = .findInPageMenuNew
    let shareIcon: NSImage = .shareMenuNew
    let printIcon: NSImage = .printMenuNew
    let helpIcon: NSImage = .helpMenuNew
    let settingsIcon: NSImage = .settingsMenuNew
    let browserFeedbackIcon: NSImage = .sendBrowserFeedbackMenuNew
    let reportBrokenSiteIcon: NSImage = .reportBrokenSiteMenuNew
    let sendPrivacyProFeedbackIcon: NSImage = .sendPrivacyProFeedbackMenuNew
    let passwordsSubMenuIcon: NSImage = .passwordMenuNew
    let identitiesIcon: NSImage = .identitiesMenuNew
    let creditCardsIcon: NSImage = .creditCardsMenuNew
    let vpnIcon: NSImage = .vpnNew
    let personalInformationRemovalIcon: NSImage = .personalInformationRemovalMenuNew
    let identityTheftRestorationIcon: NSImage = .identityTheftRestorationMenuNew
    let emailGenerateAddressIcon: NSImage = .emailGenerateAddressMenuNew
    let emailManageAccount: NSImage = .emailManageAccountMenuNew
    let emailProtectionTurnOffIcon: NSImage = .emailDisabledMenuNew
    let emailProtectionTurnOnIcon: NSImage = .emailOptionsMenuNew
    let favoritesIcon: NSImage = .favoriteMenuNew
}
