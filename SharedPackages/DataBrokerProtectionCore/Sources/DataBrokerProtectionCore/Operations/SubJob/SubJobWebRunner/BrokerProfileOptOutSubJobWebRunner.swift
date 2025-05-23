//
//  BrokerProfileOptOutSubJobWebRunner.swift
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
import WebKit
import BrowserServicesKit
import UserScript
import os.log
import Common

public protocol BrokerProfileOptOutSubJobWebRunning {
    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
                showWebView: Bool,
                shouldRunNextStep: @escaping () -> Bool) async throws
}

public final class BrokerProfileOptOutSubJobWebRunner: SubJobWebRunning, BrokerProfileOptOutSubJobWebRunning {
    public typealias ReturnValue = Void
    public typealias InputValue = ExtractedProfile

    public let privacyConfig: PrivacyConfigurationManaging
    public let prefs: ContentScopeProperties
    public let query: BrokerProfileQueryData
    public let emailService: EmailServiceProtocol
    public let captchaService: CaptchaServiceProtocol
    public let cookieHandler: CookieHandler
    public let stageCalculator: StageDurationCalculator
    public var webViewHandler: WebViewHandler?
    public var actionsHandler: ActionsHandler?
    public var continuation: CheckedContinuation<Void, Error>?
    public var extractedProfile: ExtractedProfile?
    private let operationAwaitTime: TimeInterval
    public let shouldRunNextStep: () -> Bool
    public let clickAwaitTime: TimeInterval
    public let pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>
    public var postLoadingSiteStartTime: Date?

    // Captcha is a third-party resource that sometimes takes more time to load
    // if we are not able to get the captcha information. We will try to run the action again
    // instead of failing the whole thing.
    //
    // https://app.asana.com/0/1203581873609357/1205476538384291/f
    public var retriesCountOnError: Int = 3

    public init(privacyConfig: PrivacyConfigurationManaging,
                prefs: ContentScopeProperties,
                query: BrokerProfileQueryData,
                emailService: EmailServiceProtocol,
                captchaService: CaptchaServiceProtocol,
                cookieHandler: CookieHandler = BrokerCookieHandler(),
                operationAwaitTime: TimeInterval = 3,
                clickAwaitTime: TimeInterval = 40,
                stageCalculator: StageDurationCalculator,
                pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>,
                shouldRunNextStep: @escaping () -> Bool) {
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.query = query
        self.emailService = emailService
        self.captchaService = captchaService
        self.operationAwaitTime = operationAwaitTime
        self.stageCalculator = stageCalculator
        self.shouldRunNextStep = shouldRunNextStep
        self.clickAwaitTime = clickAwaitTime
        self.cookieHandler = cookieHandler
        self.pixelHandler = pixelHandler
    }

    public func optOut(profileQuery: BrokerProfileQueryData,
                       extractedProfile: ExtractedProfile,
                       showWebView: Bool,
                       shouldRunNextStep: @escaping () -> Bool) async throws {
        try await run(inputValue: extractedProfile, showWebView: showWebView)
    }

    public func run(inputValue: ExtractedProfile,
                    webViewHandler: WebViewHandler? = nil,
                    actionsHandler: ActionsHandler? = nil,
                    showWebView: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.extractedProfile = inputValue.merge(with: query.profileQuery)
            self.continuation = continuation

            Task {
                await initialize(handler: webViewHandler,
                                 isFakeBroker: query.dataBroker.isFakeBroker,
                                 showWebView: showWebView)

                if let optOutStep = query.dataBroker.optOutStep() {
                    if let actionsHandler = actionsHandler {
                        self.actionsHandler = actionsHandler
                    } else {
                        self.actionsHandler = ActionsHandler(step: optOutStep)
                    }

                    if self.shouldRunNextStep() {
                        await executeNextStep()
                    } else {
                        failed(with: DataBrokerProtectionError.cancelled)
                    }

                } else {
                    // If we try to run an optout on a broker without an optout step, we throw.
                    failed(with: DataBrokerProtectionError.noOptOutStep)
                }
            }
        }
    }

    public func extractedProfiles(profiles: [ExtractedProfile], meta: [String: Any]?) async {
        // No - op
    }

    public func executeNextStep() async {
        retriesCountOnError = 0 // We reset the retries on error when it is successful
        Logger.action.debug("OPTOUT Waiting \(self.operationAwaitTime, privacy: .public) seconds...")
        try? await Task.sleep(nanoseconds: UInt64(operationAwaitTime) * 1_000_000_000)

        if let action = actionsHandler?.nextAction(), self.shouldRunNextStep() {
            stageCalculator.setLastActionId(action.id)
            await runNextAction(action)
        } else {
            await webViewHandler?.finish() // If we executed all steps we release the web view
            complete(())
        }
    }
}
