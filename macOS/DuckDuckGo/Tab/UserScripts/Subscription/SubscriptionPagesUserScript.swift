//
//  SubscriptionPagesUserScript.swift
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

import Foundation
import BrowserServicesKit
import Common
import Combine
import Navigation
import WebKit
import UserScript
import Subscription
import PixelKit

public extension Notification.Name {
    static let subscriptionPageCloseAndOpenPreferences = Notification.Name("com.duckduckgo.subscriptionPage.CloseAndOpenPreferences")
    static let subscriptionUpgradeFromFreemium = Notification.Name("com.duckduckgo.subscriptionPage.UpgradeFromFreemium")
}

/// The user script that will be the broker for all subscription features
public final class SubscriptionPagesUserScript: NSObject, UserScript, UserScriptMessaging {
    public var source: String = ""
    public static let context = "subscriptionPages"

    // special pages messaging cannot be isolated as we'll want regular page-scripts to be able to communicate
    public let broker = UserScriptMessageBroker(context: SubscriptionPagesUserScript.context, requiresRunInPageContentWorld: true )
    public let messageNames: [String] = [SubscriptionPagesUserScript.context]
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
}

extension SubscriptionPagesUserScript: WKScriptMessageHandlerWithReply {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) async -> (Any?, String?) {
        let action = broker.messageHandlerFor(message)
        do {
            let json = try await broker.execute(action: action, original: message)
            return (json, nil)
        } catch {
            // forward uncaught errors to the client
            return (nil, error.localizedDescription)
        }
    }
}

/// Fallback for macOS 10.15
extension SubscriptionPagesUserScript: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // unsupported
    }
}
