//
//  SpecialErrorPagesTests.swift
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

import XCTest
@testable import SpecialErrorPages
import UserScript
import WebKit

// swiftlint:disable weak_delegate
final class SpecialErrorPageUserScriptTests: XCTestCase {

    var delegate: CapturingSpecialErrorPageUserScriptDelegate!
    var userScript: SpecialErrorPageUserScript!

    override func setUpWithError() throws {
        delegate = CapturingSpecialErrorPageUserScriptDelegate()
        userScript = SpecialErrorPageUserScript(localeStrings: "", languageCode: "")
        userScript.delegate = delegate
    }

    override func tearDownWithError() throws {
        delegate = nil
        userScript = nil
    }

    func test_FeatureHasCorrectName() throws {
        XCTAssertEqual(userScript.featureName, "special-error")
    }

    func test_BrokerIsCorrectlyAdded() throws {
        // WHEN
        let broker = UserScriptMessageBroker(context: "some contect")
        userScript.with(broker: broker)

        // THEN
        XCTAssertEqual(userScript.broker, broker)
    }

    @MainActor
    func test_WhenHandlerForInitialSetUpCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "initialSetup")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForReportInitExceptionCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "reportInitException")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForReportPageExceptionCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "reportPageException")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForLeaveSiteCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "leaveSite")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForVisitSiteCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "visitSite")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForAdvancedInfoPresentedCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "advancedInfoPresented")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForInitialSetUpCalled_AndIsEnabledTrue_ThenRightParameterReturned() async {
        // GIVEN
        let expectedData = SpecialErrorData.ssl(type: .invalid, domain: "someDomain", eTldPlus1: nil)
        var encodable: Encodable?
        userScript.isEnabled = true
        delegate.errorData = expectedData

        // WHEN
        let handler = userScript.handler(forMethodNamed: "initialSetup")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNotNil(encodable)
        let data = encodable as? SpecialErrorPageUserScript.InitialSetupResult
        XCTAssertEqual(data?.platform.name, "macos")
        XCTAssertEqual(data?.errorData, expectedData)
    }

    @MainActor
    func test_WhenHandlerForLeaveSiteCalled_AndIsEnabledTrue_ThenLeaveSiteCalled() async {
        // GIVEN
        var encodable: Encodable?
        userScript.isEnabled = true

        // WHEN
        let handler = userScript.handler(forMethodNamed: "leaveSite")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNil(encodable)
        XCTAssertTrue(delegate.leaveSiteCalled)
        XCTAssertFalse(delegate.visitSiteCalled)
    }

    @MainActor
    func test_WhenHandlerForVisitSiteCalled_AndIsEnabledTrue_ThenVisitSiteCalled() async {
        // GIVEN
        var encodable: Encodable?
        userScript.isEnabled = true

        // WHEN
        let handler = userScript.handler(forMethodNamed: "visitSite")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNil(encodable)
        XCTAssertTrue(delegate.visitSiteCalled)
        XCTAssertFalse(delegate.leaveSiteCalled)
    }

    @MainActor
    func test_WhenHandlerAdvancedInfoPresentedCalled_AndIsEnabledTrue_ThenAdvancedInfoPresentedCalled() async {
        // GIVEN
        var encodable: Encodable?
        userScript.isEnabled = true

        // WHEN
        let handler = userScript.handler(forMethodNamed: "advancedInfo")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNil(encodable)
        XCTAssertTrue(delegate.advancedInfoPresentedCalled)
    }

}

class CapturingSpecialErrorPageUserScriptDelegate: SpecialErrorPageUserScriptDelegate {
    var errorData: SpecialErrorData?
    var leaveSiteCalled = false
    var visitSiteCalled = false
    var advancedInfoPresentedCalled = false

    func leaveSiteAction() {
        leaveSiteCalled = true
    }

    func visitSiteAction() {
        visitSiteCalled = true
    }

    func advancedInfoPresented() {
        advancedInfoPresentedCalled = true
    }
}
