//
//  AIChatUserScriptHandling.swift
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

import UserScript

protocol AIChatUserScriptHandling {
    func handleGetUserValues(params: Any, message: UserScriptMessage) -> Encodable?
    func openAIChatSettings(params: Any, message: UserScriptMessage) async -> Encodable?
    func getAIChatNativeConfigValues(params: Any, message: UserScriptMessage) -> Encodable?
    func closeAIChat(params: Any, message: UserScriptMessage) -> Encodable?
    func getAIChatNativePrompt(params: Any, message: UserScriptMessage) -> Encodable?
}

struct AIChatUserScriptHandler: AIChatUserScriptHandling {

    private var platform: String {
        "macOS"
    }

    public struct UserValues: Codable {
        let isToolbarShortcutEnabled: Bool
        let platform: String
    }

    private let storage: AIChatPreferencesStorage

    init(storage: AIChatPreferencesStorage) {
        self.storage = storage
    }

    @MainActor public func openAIChatSettings(params: Any, message: UserScriptMessage) -> Encodable? {
        WindowControllersManager.shared.showTab(with: .settings(pane: .aiChat))
        return nil
    }

    public func handleGetUserValues(params: Any, message: UserScriptMessage) -> Encodable? {
        UserValues(isToolbarShortcutEnabled: storage.shouldDisplayToolbarShortcut,
                   platform: platform)
    }

    public func getAIChatNativeConfigValues(params: Any, message: UserScriptMessage) -> Encodable? {
        AIChatNativeConfigValues(isAIChatHandoffEnabled: false,
                                 platform: platform,
                                 supportsClosingAIChat: true,
                                 supportsOpeningSettings: true,
                                 supportsNativePrompt: true)
    }

    func closeAIChat(params: Any, message: UserScriptMessage) -> Encodable? {
        Task { @MainActor in
            WindowControllersManager.shared.mainWindowController?.mainViewController.closeTab(nil)
        }
        return nil
    }

    func getAIChatNativePrompt(params: Any, message: UserScriptMessage) -> Encodable? {
        AIChatNativePrompt(platform: platform,
                           query: .init(prompt: "How many potatos are too many potatoes?",
                                        autoSubmit: true))
    }
}

private struct AIChatNativeConfigValues: Codable {
    let isAIChatHandoffEnabled: Bool
    let platform: String
    let supportsClosingAIChat: Bool
    let supportsOpeningSettings: Bool
    let supportsNativePrompt: Bool
}

private struct AIChatNativePrompt: Codable {
    struct Query: Codable {
        let prompt: String
        let autoSubmit: Bool
    }

    let platform: String
    let query: Query?
}
