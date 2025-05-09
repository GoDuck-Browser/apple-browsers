//
//  ContextualDaxDialogsFactoryTests.swift
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
import SwiftUI
import Core
import Onboarding
@testable import DuckDuckGo

final class ContextualDaxDialogsFactoryTests: XCTestCase {
    private var sut: ExperimentContextualDaxDialogsFactory!
    private var delegate: ContextualOnboardingDelegateMock!
    private var settingsMock: ContextualOnboardingSettingsMock!
    private var pixelReporterMock: OnboardingPixelReporterMock!
    private var onboardingManagerMock: OnboardingManagerMock!
    private var contextualOnboardingLogicMock: ContextualOnboardingLogicMock!
    private var window: UIWindow!

    override func setUpWithError() throws {
        delegate = ContextualOnboardingDelegateMock()
        settingsMock = ContextualOnboardingSettingsMock()
        pixelReporterMock = OnboardingPixelReporterMock()
        onboardingManagerMock = OnboardingManagerMock()
        contextualOnboardingLogicMock = ContextualOnboardingLogicMock()
        sut = ExperimentContextualDaxDialogsFactory(
            contextualOnboardingLogic: contextualOnboardingLogicMock,
            contextualOnboardingSettings: settingsMock,
            contextualOnboardingPixelReporter: pixelReporterMock,
            onboardingManager: onboardingManagerMock
        )
        window = UIWindow(frame: UIScreen.main.bounds)
        window.isHidden = false
    }

    override func tearDownWithError() throws {
        window?.isHidden = true
        window = nil
        delegate = nil
        settingsMock = nil
        pixelReporterMock = nil
        onboardingManagerMock = nil
        contextualOnboardingLogicMock = nil
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - After Search

    func testWhenMakeViewForAfterSearchSpecThenCreatesOnboardingFirstSearchDoneDialog() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.afterSearch

        // WHEN
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertTrue(view.viewModel.delegate === delegate)
    }

    func test_WhenMakeViewForAfterSearchSpec_AndActionIsTapped_AndTrackersDialogHasShown_ThenDidTapDismissContextualOnboardingActionIsCalledOnDelegate() throws {
        // GIVEN
        settingsMock.userHasSeenTrackersDialog = true
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
        XCTAssertFalse(delegate.didCallDidAcknowledgeContextualOnboardingSearch)
    }

    func test_WhenMakeViewForAfterSearchSpec_AndActionIsTapped_AndTrackersDialogHasNotShown_ThenDidTapDismissContextualOnboardingActionIsCalledOnDelegate() throws {
        // GIVEN
        settingsMock.userHasSeenTrackersDialog = false
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)
        XCTAssertTrue(delegate.didCallDidAcknowledgeContextualOnboardingSearch)
    }

    // MARK: - Visit Website

    func test_WhenMakeViewForVisitWebsiteSpec_AndActionIsTapped_AndTrackersDialogHasShown_ThenNavigateToActionIsCalledOnDelegate() throws {
        // GIVEN
        settingsMock.userHasSeenTrackersDialog = true
        let spec = DaxDialogs.BrowsingSpec(type: .visitWebsite, pixelName: .onboardingIntroShownUnique)
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingTryVisitingSiteDialog.self, in: result))
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        let urlString = "some.site"
        view.viewModel.listItemPressed(ContextualOnboardingListItem.site(title: urlString))

        // THEN
        XCTAssertTrue(delegate.didCallNavigateToURL)
        XCTAssertEqual(delegate.urlToNavigateTo, URL(string: urlString))
    }

    // MARK: - Trackers

    func test_WhenMakeViewForTrackerSpec_ThenReturnViewOnboardingTrackersDoneDialog() throws {
        // GIVEN
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // WHEN
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})

            // THEN
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertNotNil(view)
        }
    }

    func test_WhenMakeViewForTrackerSpec_AndFireDialogHasNotShown_ThenActionCallsDidAcknowledgeContextualOnboardingTrackersDialog() throws {
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // GIVEN
            delegate = ContextualOnboardingDelegateMock()
            settingsMock.userHasSeenFireDialog = false
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertFalse(delegate.didCallDidAcknowledgeContextualOnboardingTrackersDialog)

            // WHEN
            view.blockedTrackersCTAAction()

            // THEN
            XCTAssertTrue(delegate.didCallDidAcknowledgeContextualOnboardingTrackersDialog)
        }
    }

    func test_WhenMakeViewForTrackerSpec_AndFireDialogHasShown_ThenActionCallsDidTapDismissContextualOnboardingAction() throws {
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // GIVEN
            delegate = ContextualOnboardingDelegateMock()
            settingsMock.userHasSeenFireDialog = true
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

            // WHEN
            view.blockedTrackersCTAAction()

            // THEN
            XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
        }
    }

    // MARK: - Fire
    func test_WhenMakeViewFire_ThenReturnViewOnboardingFireDialog() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec(type: .fire, pixelName: .onboardingIntroShownUnique)

        // WHEN
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFireDialog.self, in: result))
        XCTAssertNotNil(view)
    }

    // MARK: - Final

    func test_WhenMakeViewForFinalSpec_ThenReturnViewOnboardingFinalDialog() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.final

        // WHEN
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))
        XCTAssertNotNil(view)
    }

    func test_WhenCallActionOnOnboardingFinalDialog_ThenDidTapDismissContextualOnboardingActionOnDelegateIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.final
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.dismissAction()

        // THEN
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

    // MARK: - Pixels

    func testWhenViewForAfterSearchSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let expectedPixel = Pixel.Event.daxDialogsSerpUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForVisitSiteSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.visitWebsite
        let expectedPixel = Pixel.Event.onboardingContextualTryVisitSiteUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForWithoutTrackersSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.withoutTrackers
        let expectedPixel = Pixel.Event.daxDialogsWithoutTrackersUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForWithOneTrackerSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.withOneTracker
        let expectedPixel = Pixel.Event.daxDialogsWithTrackersUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForWithTrackersSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.withMultipleTrackers
        let expectedPixel = Pixel.Event.daxDialogsWithTrackersUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForSiteIsMajorTrackerSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.siteIsMajorTracker
        let expectedPixel = Pixel.Event.daxDialogsSiteIsMajorUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForSiteIsOwnedByMajorTrackerSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.siteOwnedByMajorTracker
        let expectedPixel = Pixel.Event.daxDialogsSiteOwnedByMajorUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForFireSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.fire
        let expectedPixel = Pixel.Event.daxDialogsFireEducationShownUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenViewForFinalSpecAppearsThenExpectedPixelFires() {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.final
        let expectedPixel = Pixel.Event.daxDialogsEndOfJourneyTabUnique
        // TEST
        testDialogDefinedBy(spec: spec, firesEvent: expectedPixel)
    }

    func testWhenAfterSearchCTAIsTappedAndTryVisitWebsiteDialogThenExpectedPixelFires() throws {
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // GIVEN
            settingsMock.userHasSeenFireDialog = false
            pixelReporterMock = OnboardingPixelReporterMock()
            sut = ExperimentContextualDaxDialogsFactory(
                contextualOnboardingLogic: ContextualOnboardingLogicMock(),
                contextualOnboardingSettings: settingsMock,
                contextualOnboardingPixelReporter: pixelReporterMock
            )
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertFalse(pixelReporterMock.didCallMeasureScreenImpressionCalled)
            XCTAssertNil(pixelReporterMock.capturedScreenImpression)

            // WHEN
            view.blockedTrackersCTAAction()

            // THEN
            XCTAssertTrue(pixelReporterMock.didCallMeasureScreenImpressionCalled)
            XCTAssertEqual(pixelReporterMock.capturedScreenImpression, .daxDialogsFireEducationShownUnique)
        }
    }

    func testWhenTrackersDialogCTAIsTappedAndFireDialogThenExpectedPixelFires() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureScreenImpressionCalled)
        XCTAssertNil(pixelReporterMock.capturedScreenImpression)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureScreenImpressionCalled)
        XCTAssertEqual(pixelReporterMock.capturedScreenImpression, .onboardingContextualTryVisitSiteUnique)
    }

    func testWhenEndOfJourneyDialogCTAIsTappedThenExpectedPixelFires() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.final
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureEndOfJourneyDialogDismiss)

        // WHEN
        view.dismissAction()

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureEndOfJourneyDialogDismiss)
    }

    // MARK: - Manual Dismiss Dialog

    func testWhenSearchResultDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let isShowingTryVisitSiteDialog = false
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureSearchResultDialogDismissButtonTapped)
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)


        // WHEN
        view.onManualDismiss(isShowingTryVisitSiteDialog)

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureSearchResultDialogDismissButtonTapped)
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

    func testWhenTryVisitSiteFromSearchResultDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.afterSearch
        let isShowingTryVisitSiteDialog = true
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureTryVisitSiteDismissButtonTapped)
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)


        // WHEN
        view.onManualDismiss(isShowingTryVisitSiteDialog)

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureTryVisitSiteDismissButtonTapped)
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

    func testWhenTryVisitSiteDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.visitWebsite
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingTryVisitingSiteDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureTryVisitSiteDismissButtonTapped)
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.onManualDismiss()

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureTryVisitSiteDismissButtonTapped)
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

    func testWhenFireDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.fire
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFireDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureFireDialogDismissButtonTapped)
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.onManualDismiss()

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureFireDialogDismissButtonTapped)
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

    func testWhenTrackersDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // GIVEN
            let isShowingFireDialog = false
            pixelReporterMock = OnboardingPixelReporterMock()
            delegate = ContextualOnboardingDelegateMock()
            contextualOnboardingLogicMock = ContextualOnboardingLogicMock()
            sut = ExperimentContextualDaxDialogsFactory(
                contextualOnboardingLogic: contextualOnboardingLogicMock,
                contextualOnboardingSettings: settingsMock,
                contextualOnboardingPixelReporter: pixelReporterMock
            )
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertFalse(pixelReporterMock.didCallMeasureTrackersDialogDismissButtonTapped)
            XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)
            XCTAssertFalse(contextualOnboardingLogicMock.didCallSetFireEducationMessageSeen)

            // WHEN
            view.onManualDismiss(isShowingFireDialog)

            // THEN
            XCTAssertTrue(pixelReporterMock.didCallMeasureTrackersDialogDismissButtonTapped)
            XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
            XCTAssertTrue(contextualOnboardingLogicMock.didCallSetFireEducationMessageSeen)
        }
    }

    func testWhenFireDialogFromTrackersDialogDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        try [DaxDialogs.BrowsingSpec.siteIsMajorTracker, .siteOwnedByMajorTracker, .withMultipleTrackers, .withoutTrackers, .withoutTrackers].forEach { spec in
            // GIVEN
            let isShowingFireDialog = true
            pixelReporterMock = OnboardingPixelReporterMock()
            delegate = ContextualOnboardingDelegateMock()
            contextualOnboardingLogicMock = ContextualOnboardingLogicMock()
            sut = ExperimentContextualDaxDialogsFactory(
                contextualOnboardingLogic: contextualOnboardingLogicMock,
                contextualOnboardingSettings: settingsMock,
                contextualOnboardingPixelReporter: pixelReporterMock
            )
            let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
            let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
            XCTAssertFalse(pixelReporterMock.didCallMeasureFireDialogDismissButtonTapped)
            XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)
            XCTAssertFalse(contextualOnboardingLogicMock.didCallSetFireEducationMessageSeen)

            // WHEN
            view.onManualDismiss(isShowingFireDialog)

            // THEN
            XCTAssertTrue(pixelReporterMock.didCallMeasureFireDialogDismissButtonTapped)
            XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
            XCTAssertFalse(contextualOnboardingLogicMock.didCallSetFireEducationMessageSeen)
        }
    }

    func testWhenEndOfJourneyDismissCTAIsTappedThenExpectedPixelFiresAndDelegateDidTapDismissIsCalled() throws {
        // GIVEN
        let spec = DaxDialogs.BrowsingSpec.final
        let result = sut.makeView(for: spec, delegate: delegate, onSizeUpdate: {})
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))
        XCTAssertFalse(pixelReporterMock.didCallMeasureEndOfJourneyDialogDismissButtonTapped)
        XCTAssertFalse(delegate.didCallDidTapDismissContextualOnboardingAction)

        // WHEN
        view.onManualDismiss()

        // THEN
        XCTAssertTrue(pixelReporterMock.didCallMeasureEndOfJourneyDialogDismissButtonTapped)
        XCTAssertTrue(delegate.didCallDidTapDismissContextualOnboardingAction)
    }

}

extension ContextualDaxDialogsFactoryTests {

    func testDialogDefinedBy(spec: DaxDialogs.BrowsingSpec, firesEvent event: Pixel.Event) {
        waitForDialogDefinedBy(spec: spec) {
            // THEN
            XCTAssertTrue(self.pixelReporterMock.didCallMeasureScreenImpressionCalled)
            XCTAssertEqual(self.pixelReporterMock.capturedScreenImpression, event)
        }
    }

    func waitForDialogDefinedBy(spec: DaxDialogs.BrowsingSpec, completionHandler: @escaping () -> Void) {
        // GIVEN
        let expectation = self.expectation(description: #function)
        XCTAssertFalse(pixelReporterMock.didCallMeasureScreenImpressionCalled)
        XCTAssertNil(pixelReporterMock.capturedScreenImpression)

        // WHEN
        let view = sut.makeView(for: spec, delegate: ContextualOnboardingDelegateMock(), onSizeUpdate: {}).rootView
        let host = OnboardingHostingControllerMock(rootView: AnyView(view))
        host.onAppearExpectation = expectation
        window.rootViewController = host
        XCTAssertNotNil(host.view)

        // THEN
        waitForExpectations(timeout: 2)
        completionHandler()
    }

}

final class ContextualOnboardingSettingsMock: ContextualOnboardingSettings {
    var userHasSeenTrackersDialog: Bool = false
    var userHasSeenFireDialog: Bool = false
    var userHasSeenTryVisitSiteDialog: Bool = false
}


final class ContextualOnboardingDelegateMock: ContextualOnboardingDelegate {
    private(set) var didCallDidShowContextualOnboardingTrackersDialog = false
    private(set) var didCallDidAcknowledgeContextualOnboardingTrackersDialog = false
    private(set) var didCallDidTapDismissContextualOnboardingAction = false
    private(set) var didCallSearchForQuery = false
    private(set) var didCallNavigateToURL = false
    private(set) var didCallDidAcknowledgeContextualOnboardingSearch = false
    private(set) var urlToNavigateTo: URL?

    func didShowContextualOnboardingTrackersDialog() {
        didCallDidShowContextualOnboardingTrackersDialog = true
    }
    
    func didAcknowledgeContextualOnboardingTrackersDialog() {
        didCallDidAcknowledgeContextualOnboardingTrackersDialog = true
    }
    
    func didTapDismissContextualOnboardingAction() {
        didCallDidTapDismissContextualOnboardingAction = true
    }

    func searchFromOnboarding(for query: String) {
        didCallSearchForQuery = true
    }
    
    func navigateFromOnboarding(to url: URL) {
        didCallNavigateToURL = true
        urlToNavigateTo = url
    }

    func didAcknowledgeContextualOnboardingSearch() {
        didCallDidAcknowledgeContextualOnboardingSearch = true
    }

}
