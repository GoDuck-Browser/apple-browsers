//
//  AIChatMenuConfigurationTests.swift
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
import XCTest
import Combine
import AIChat
@testable import DuckDuckGo_Privacy_Browser

class AIChatMenuConfigurationTests: XCTestCase {
    var configuration: AIChatMenuConfiguration!
    var mockStorage: MockAIChatPreferencesStorage!
    var remoteSettings: MockRemoteAISettings!

    override func setUp() {
        super.setUp()
        mockStorage = MockAIChatPreferencesStorage()
        remoteSettings = MockRemoteAISettings()
        configuration = AIChatMenuConfiguration(storage: mockStorage, remoteSettings: remoteSettings)
    }

    override func tearDown() {
        configuration = nil
        mockStorage = nil
        remoteSettings = nil
        super.tearDown()
    }

    func testShouldDisplayApplicationMenuShortcut() {
        mockStorage.showShortcutInApplicationMenu = true
        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertTrue(result, "Application menu shortcut should be displayed when enabled.")
    }

    func testShouldDisplayAddressBarShortcut() {
        mockStorage.showShortcutInAddressBar = true
        let result = configuration.shouldDisplayAddressBarShortcut

        XCTAssertTrue(result, "Address bar shortcut should be displayed when enabled.")
    }

    func testAddressBarValuesChangedPublisher() {
        let expectation = self.expectation(description: "Values changed publisher should emit a value.")

        let cancellable = configuration.valuesChangedPublisher.sink {
            expectation.fulfill()
        }

        mockStorage.updateAddressBarShortcutDisplay(to: true)

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Values changed publisher did not emit a value in time.")
        }
        cancellable.cancel()
    }

    func testApplicationMenuValuesChangedPublisher() {
        let expectation = self.expectation(description: "Values changed publisher should emit a value.")

        let cancellable = configuration.valuesChangedPublisher.sink { value in
            expectation.fulfill()
        }

        mockStorage.updateApplicationMenuShortcutDisplay(to: true)

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Values changed publisher did not emit a value in time.")
        }
        cancellable.cancel()
    }

    func testShouldNotDisplayAddressBarShortcutWhenDisabled() {
        mockStorage.showShortcutInAddressBar = false
        let result = configuration.shouldDisplayAddressBarShortcut

        XCTAssertFalse(result, "Address bar shortcut should not be displayed when disabled.")
    }

    func testReset() {
        mockStorage.showShortcutInApplicationMenu = true
        mockStorage.showShortcutInAddressBar = true
        mockStorage.didDisplayAIChatAddressBarOnboarding = true

        mockStorage.reset()

        XCTAssertFalse(mockStorage.showShortcutInApplicationMenu, "Application menu shortcut should be reset to false.")
        XCTAssertFalse(mockStorage.showShortcutInAddressBar, "Address bar shortcut should be reset to false.")
        XCTAssertFalse(mockStorage.didDisplayAIChatAddressBarOnboarding, "Address bar onboarding popover should be reset to false.")
    }

    func testShouldDisplayAddressBarShortcutWhenRemoteFlagAndStorageAreTrue() {
        remoteSettings.isAddressBarShortcutEnabled = true
        mockStorage.showShortcutInAddressBar = true

        let result = configuration.shouldDisplayAddressBarShortcut

        XCTAssertTrue(result, "Address bar shortcut should be displayed when both remote flag and storage are true.")
    }

    func testShouldDisplayApplicationMenuShortcutWhenRemoteFlagAndStorageAreTrue() {
        remoteSettings.isApplicationMenuShortcutEnabled = true
        mockStorage.showShortcutInApplicationMenu = true

        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertTrue(result, "Application menu shortcut should be displayed when both remote flag and storage are true.")
    }
}

class MockAIChatPreferencesStorage: AIChatPreferencesStorage {
    var didDisplayAIChatAddressBarOnboarding: Bool = false

    var showShortcutInApplicationMenu: Bool = false {
        didSet {
            showShortcutInApplicationMenuSubject.send(showShortcutInApplicationMenu)
        }
    }

    var showShortcutInAddressBar: Bool = false {
        didSet {
            showShortcutInAddressBarSubject.send(showShortcutInAddressBar)
        }
    }

    private var showShortcutInApplicationMenuSubject = PassthroughSubject<Bool, Never>()
    private var showShortcutInAddressBarSubject = PassthroughSubject<Bool, Never>()

    var showShortcutInApplicationMenuPublisher: AnyPublisher<Bool, Never> {
        showShortcutInApplicationMenuSubject.eraseToAnyPublisher()
    }

    var showShortcutInAddressBarPublisher: AnyPublisher<Bool, Never> {
        showShortcutInAddressBarSubject.eraseToAnyPublisher()
    }

    func reset() {
        showShortcutInApplicationMenu = false
        showShortcutInAddressBar = false
        didDisplayAIChatAddressBarOnboarding = false
    }

    func updateApplicationMenuShortcutDisplay(to value: Bool) {
        showShortcutInApplicationMenu = value
    }

    func updateAddressBarShortcutDisplay(to value: Bool) {
        showShortcutInAddressBar = value
    }
}

final class MockRemoteAISettings: AIChatRemoteSettingsProvider {
    var onboardingCookieName: String
    var onboardingCookieDomain: String
    var aiChatURLIdentifiableQuery: String
    var aiChatURLIdentifiableQueryValue: String
    var aiChatURL: URL
    var isAIChatEnabled: Bool
    var isAddressBarShortcutEnabled: Bool
    var isApplicationMenuShortcutEnabled: Bool

    init(onboardingCookieName: String = "defaultCookie",
         onboardingCookieDomain: String = "defaultdomain.com",
         aiChatURLIdentifiableQuery: String = "defaultQuery",
         aiChatURLIdentifiableQueryValue: String = "defaultValue",
         aiChatURL: URL = URL(string: "https://duck.com/chat")!,
         isAIChatEnabled: Bool = true,
         isAddressBarShortcutEnabled: Bool = true,
         isApplicationMenuShortcutEnabled: Bool = true) {
        self.onboardingCookieName = onboardingCookieName
        self.onboardingCookieDomain = onboardingCookieDomain
        self.aiChatURLIdentifiableQuery = aiChatURLIdentifiableQuery
        self.aiChatURLIdentifiableQueryValue = aiChatURLIdentifiableQueryValue
        self.aiChatURL = aiChatURL
        self.isAIChatEnabled = isAIChatEnabled
        self.isAddressBarShortcutEnabled = isAddressBarShortcutEnabled
        self.isApplicationMenuShortcutEnabled = isApplicationMenuShortcutEnabled
    }
}
