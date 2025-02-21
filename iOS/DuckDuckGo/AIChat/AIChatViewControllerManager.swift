//
//  AIChatViewControllerManager.swift
//  DuckDuckGo
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

import UserScript
import AIChat
import Foundation
import BrowserServicesKit
import WebKit
import Core
import Combine
import SwiftUI

protocol AIChatViewControllerManagerDelegate: AnyObject {
    func aiChatViewControllerManager(_ manager: AIChatViewControllerManager, didRequestToLoad url: URL)
}

final class AIChatViewControllerManager {
    weak var delegate: AIChatViewControllerManagerDelegate?
    private var aiChatUserScript: AIChatUserScript?
    private var payloadHandler = AIChatPayloadHandler()
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private weak var userContentController: UserContentController?
    private var cancellables = Set<AnyCancellable>()

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
        subscribeToNotifications()
    }

    private func subscribeToNotifications() {
        NotificationCenter.default.publisher(for: Notification.Name(rawValue: "TEXT_TO_SPEECH"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let content = notification.object as? TextToSpeechContent {
                    self?.openSpeechView(content)
                }

            }
            .store(in: &cancellables)
    }

    func openSpeechView(_ content: TextToSpeechContent) {
        let speechView = SpeechView(text: content.readableContent, isShowingSheet: .constant(true))

        let hostingController = UIHostingController(rootView: speechView)

        if let topViewController = topMostViewController() {
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.selectedDetentIdentifier = .medium // Set the initial detent
            }

            topViewController.present(hostingController, animated: true, completion: nil)
        }
    }

    /// Hackdays code, don't judge me
    private func topMostViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            return nil
        }
        var topController: UIViewController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
    @MainActor
    func openAIChat(_ query: String? = nil, payload: Any? = nil, autoSend: Bool = false, on viewController: UIViewController) {
        let settings = AIChatSettings(privacyConfigurationManager: privacyConfigurationManager)

        // Check if the viewController is already presenting a RoundedPageSheetContainerViewController with AIChatViewController inside
        if let presentedVC = viewController.presentedViewController as? RoundedPageSheetContainerViewController,
           presentedVC.contentViewController is AIChatViewController {
            return
        } else {
            viewController.dismiss(animated: true)
        }

        let webviewConfiguration = WKWebViewConfiguration.persistent()
        let userContentController = UserContentController()
        userContentController.delegate = self

        webviewConfiguration.userContentController = userContentController
        self.userContentController = userContentController
        let aiChatViewController = AIChatViewController(settings: settings,
                                                        webViewConfiguration: webviewConfiguration,
                                                        requestAuthHandler: AIChatRequestAuthorizationHandler(debugSettings: AIChatDebugSettings()))
        aiChatViewController.delegate = self

        let roundedPageSheet = RoundedPageSheetContainerViewController(
            contentViewController: aiChatViewController,
            allowedOrientation: .portrait)

        roundedPageSheet.delegate = self

        if let query = query {
            aiChatViewController.loadQuery(query, autoSend: autoSend)
        }

        // Force a reload to trigger the user script getUserValues
        if let payload = payload as? AIChatPayload {
            payloadHandler.setPayload(payload)
            aiChatViewController.reload()
        }
        viewController.present(roundedPageSheet, animated: true, completion: nil)
    }

    private func cleanUpUserContent() {
        Task {
            await userContentController?.removeAllContentRuleLists()
            await userContentController?.cleanUpBeforeClosing()
        }
    }
}

extension AIChatViewControllerManager: UserContentControllerDelegate {
    @MainActor
    func userContentController(_ userContentController: UserContentController,
                               didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList],
                               userScripts: UserScriptsProvider,
                               updateEvent: ContentBlockerRulesManager.UpdateEvent) {

        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }
        self.aiChatUserScript = userScripts.aiChatUserScript
        self.aiChatUserScript?.setPayloadHandler(self.payloadHandler)
    }
}

// MARK: - AIChatViewControllerDelegate
extension AIChatViewControllerManager: AIChatViewControllerDelegate {
    func aiChatViewController(_ viewController: AIChatViewController, didRequestToLoad url: URL) {
        delegate?.aiChatViewControllerManager(self, didRequestToLoad: url)
        viewController.dismiss(animated: true)
    }

    func aiChatViewControllerDidFinish(_ viewController: AIChatViewController) {
        viewController.dismiss(animated: true)
    }
}

// MARK: - RoundedPageSheetContainerViewControllerDelegate
extension AIChatViewControllerManager: RoundedPageSheetContainerViewControllerDelegate {
    func roundedPageSheetContainerViewControllerDidDisappear(_ controller: RoundedPageSheetContainerViewController) {
        cleanUpUserContent()
    }
}
