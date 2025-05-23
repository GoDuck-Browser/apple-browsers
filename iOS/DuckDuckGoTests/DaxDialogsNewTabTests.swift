//
//  DaxDialogsNewTabTests.swift
//  DuckDuckGo
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
import TrackerRadarKit
@testable import DuckDuckGo

final class DaxDialogsNewTabTests: XCTestCase {

    var daxDialogs: DaxDialogs!
    var settings: DaxDialogsSettings!

    override func setUp() {
        settings = MockDaxDialogsSettings()
        let mockVariantManager = MockVariantManager(isSupportedReturns: true)
        daxDialogs = DaxDialogs(
            settings: settings,
            entityProviding: MockEntityProvider(),
            variantManager: mockVariantManager,
            onboardingPrivacyProPromotionHelper: MockOnboardingPrivacyProPromotionHelper()
        )
    }

    override func tearDown() {
        settings = nil
        daxDialogs = nil
    }

    func testIfIsAddFavoriteFlow_OnNextHomeScreenMessageNew_ReturnsAddFavorite() {
        // GIVEN
        daxDialogs.enableAddFavoriteFlow()

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        // THEN
        XCTAssertEqual(homeScreenMessage, .addFavorite)
    }

    func testIfTryAnonymousSearchNotShown_OnNextHomeScreenMessageNew_ReturnsInitial() {
        // GIVEN
        settings.tryAnonymousSearchShown = false

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        // THEN
        XCTAssertEqual(homeScreenMessage, .initial)
    }

    func testIfTryAnonymousSearchShown_AndTryVisitASiteNotShown_OnNextHomeScreenMessageNew_ReturnsSubsequent() {
        // GIVEN
        settings.tryAnonymousSearchShown = true
        settings.tryVisitASiteShown = false

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        // THEN
        XCTAssertEqual(homeScreenMessage, .subsequent)
    }

    func testIfTryAnonymousSearchShown_AndTryVisitASiteShown_AndFireDialogNotShown_OnNextHomeScreenMessageNew_ReturnsNil() {
        // GIVEN
        settings.tryAnonymousSearchShown = true
        settings.tryVisitASiteShown = true

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        // THEN
        XCTAssertNil(homeScreenMessage)
    }

    func testIfFinalDialogSeen_OnNextHomeScreenMessageNew_ReturnsNil() {
        // GIVEN
        settings.browsingFinalDialogShown = true

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        //
        XCTAssertNil(homeScreenMessage)
    }

    func testIfIsNotEnabled_OnNextHomeScreenMessageNew_ReturnsNil() {
        // GIVEN
        settings.isDismissed = true

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        //
        XCTAssertNil(homeScreenMessage)
    }

    func testIfFireDialogShow_OnNextHomeScreenMessageNew_ReturnsFinal() {
        // GIVEN
        settings.fireMessageExperimentShown = true

        // WHEN
        let homeScreenMessage = daxDialogs.nextHomeScreenMessageNew()

        // THEN
        XCTAssertEqual(homeScreenMessage, .final)
    }
}

class MockDaxDialogsSettings: DaxDialogsSettings {
    
    var isDismissed: Bool = false

    var homeScreenMessagesSeen: Int = 0

    var tryAnonymousSearchShown: Bool = false

    var tryVisitASiteShown: Bool = false

    var browsingAfterSearchShown: Bool = false

    var browsingWithTrackersShown: Bool = false

    var browsingWithoutTrackersShown: Bool = false

    var browsingMajorTrackingSiteShown: Bool = false

    var fireButtonEducationShownOrExpired: Bool = false

    var fireMessageExperimentShown: Bool = false

    var privacyButtonPulseShown: Bool = false

    var fireButtonPulseDateShown: Date?

    var browsingFinalDialogShown: Bool = false

    var privacyProPromotionDialogShown: Bool = false
}
