//
//  SmallOmniBarState.swift
//  DuckDuckGo
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

import Foundation
import Core
import BrowserServicesKit
struct SmallOmniBarState {

    struct HomeEmptyEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = true
        let allowsTrackersAnimation = false
        let showPrivacyIcon = false
        let showBackground = false
        let showClear = false
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showCancel = false
        let showDismiss = true
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEditingStartedState: OmniBarState { return self }
        var onTextClearedState: OmniBarState { return self }
        var onTextEnteredState: OmniBarState { return HomeTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStartedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStoppedState: OmniBarState { return self }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var showSearchLoupe: Bool { dependencies.shouldShowSearchLoupeIfPossible }
        var showVoiceSearch: Bool { dependencies.voiceSearchHelper.isVoiceSearchEnabled }

        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }

    struct HomeTextEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = false
        let allowsTrackersAnimation = false
        let showPrivacyIcon = false
        let showBackground = false
        let showClear = true
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showCancel = false
        let showDismiss = true
        let showVoiceSearch = false
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEditingStartedState: OmniBarState { return self }
        var onTextClearedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextEnteredState: OmniBarState { return self }
        var onBrowsingStartedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStoppedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.HomeTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return HomeTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var showSearchLoupe: Bool { dependencies.shouldShowSearchLoupeIfPossible }
        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }

    struct HomeNonEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = true
        let allowsTrackersAnimation = false
        let showSearchLoupe = true
        let showPrivacyIcon = false
        let showBackground = true
        let showClear = false
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showDismiss = false
        let showCancel = false
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return self }
        var onEditingStartedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextClearedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextEnteredState: OmniBarState { return HomeTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStartedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStoppedState: OmniBarState { return HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }

        var showVoiceSearch: Bool { dependencies.voiceSearchHelper.isVoiceSearchEnabled }

        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }

    struct BrowsingEmptyEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = true
        let allowsTrackersAnimation = false
        let showPrivacyIcon = false
        let showBackground = false
        let showClear = false
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showCancel = false
        let showDismiss = true
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEditingStartedState: OmniBarState { return self }
        var onTextClearedState: OmniBarState { return self }
        var onTextEnteredState: OmniBarState { return BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStartedState: OmniBarState { return self }
        var onBrowsingStoppedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.BrowsingEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return BrowsingEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var showSearchLoupe: Bool { dependencies.shouldShowSearchLoupeIfPossible }

        var showVoiceSearch: Bool { dependencies.voiceSearchHelper.isVoiceSearchEnabled }
        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }


    struct BrowsingTextEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = false
        let allowsTrackersAnimation = false
        let showPrivacyIcon = false
        let showBackground = false
        let showClear = true
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showCancel = false
        let showDismiss = true
        let showVoiceSearch = false
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEditingStartedState: OmniBarState { return self }
        var onTextClearedState: OmniBarState { return BrowsingEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextEnteredState: OmniBarState { return self }
        var onBrowsingStartedState: OmniBarState { return self }
        var onBrowsingStoppedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var showSearchLoupe: Bool { dependencies.shouldShowSearchLoupeIfPossible }

        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }


    struct BrowsingNonEditingState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = false
        let allowsTrackersAnimation = true
        let showSearchLoupe = false
        let showPrivacyIcon = true
        let showBackground = true
        let showClear = false
        var showAbort: Bool { isLoading }
        var showRefresh: Bool { false }
        var showShare: Bool { !isLoading }
        let showMenu = false
        let showSettings = false
        let showCancel = false
        let showVoiceSearch = false
        let showDismiss = false
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return self }
        var onEditingStartedState: OmniBarState { return BrowsingTextEditingStartedState(dependencies: dependencies, isLoading: isLoading) }
        var onTextClearedState: OmniBarState { return BrowsingEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextEnteredState: OmniBarState { return BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStartedState: OmniBarState { return self }
        var onBrowsingStoppedState: OmniBarState { return HomeNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }

        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }

    struct BrowsingTextEditingStartedState: OmniBarState, OmniBarLoadingBearerStateCreating {
        let hasLargeWidth = false
        let showBackButton = false
        let showForwardButton = false
        let showBookmarksButton = false
        var showAccessoryButton: Bool { dependencies.isAIChatEnabledInSettings }
        let clearTextOnStart = false
        let allowsTrackersAnimation = false
        let showPrivacyIcon = false
        let showBackground = false
        let showClear = true
        let showAbort = false
        let showRefresh = false
        let showShare = false
        let showMenu = false
        let showSettings = false
        let showDismiss = true
        let showCancel = false
        var name: String { return "Phone" + Type.name(self) }
        var onEditingStoppedState: OmniBarState { return BrowsingNonEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEditingStartedState: OmniBarState { return self }
        var onTextClearedState: OmniBarState { return BrowsingEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onTextEnteredState: OmniBarState { return BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onBrowsingStartedState: OmniBarState { return self }
        var onBrowsingStoppedState: OmniBarState { return HomeEmptyEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPadState: OmniBarState { return LargeOmniBarState.BrowsingTextEditingState(dependencies: dependencies, isLoading: isLoading) }
        var onEnterPhoneState: OmniBarState { return self }
        var onReloadState: OmniBarState { return BrowsingTextEditingStartedState(dependencies: dependencies, isLoading: isLoading) }
        var showSearchLoupe: Bool { dependencies.shouldShowSearchLoupeIfPossible }
        var showVoiceSearch: Bool { dependencies.voiceSearchHelper.isVoiceSearchEnabled }

        let dependencies: OmnibarDependencyProvider
        let isLoading: Bool
    }
}

extension OmnibarDependencyProvider {
    var isAIChatEnabledInSettings: Bool {
        aiChatSettings.isAIChatAddressBarUserSettingsEnabled
    }

    var shouldShowSearchLoupeIfPossible: Bool {
        return false
    }
}
