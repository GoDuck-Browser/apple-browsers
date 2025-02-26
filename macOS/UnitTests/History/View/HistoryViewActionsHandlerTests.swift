//
//  HistoryViewActionsHandlerTests.swift
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

import History
import HistoryView
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class CapturingHistoryViewDataProvider: HistoryViewDataProviding {

    var ranges: [DataModel.HistoryRange] {
        rangesCallCount += 1
        return _ranges
    }

    func refreshData() {
        resetCacheCallCount += 1
    }

    func visitsBatch(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> DataModel.HistoryItemsBatch {
        visitsBatchCalls.append(.init(query: query, limit: limit, offset: offset))
        return await visitsBatch(query, limit, offset)
    }

    func countVisibleVisits(for range: DataModel.HistoryRange) async -> Int {
        countVisibleVisitsForRangeCalls.append(range)
        return await countVisibleVisitsForRange(range)
    }

    func countVisibleVisits(matching searchTerm: String) async -> Int {
        countVisibleVisitsMatchingSearchTermCalls.append(searchTerm)
        return await countVisibleVisitsMatchingSearchTerm(searchTerm)
    }

    func deleteVisits(for range: DataModel.HistoryRange) async {
        deleteVisitsForRangeCalls.append(range)
    }

    func burnVisits(for range: DataModel.HistoryRange) async {
        burnVisitsForRangeCalls.append(range)
    }

    func deleteVisits(for identifiers: [VisitIdentifier]) async {
        deleteVisitsForIdentifierCalls.append(identifiers)
    }

    func burnVisits(for identifiers: [VisitIdentifier]) async {
        burnVisitsForIdentifiersCalls.append(identifiers)
    }

    func deleteVisits(matching searchTerm: String) async {
        deleteVisitsMatchingSearchTermCalls.append(searchTerm)
    }

    func burnVisits(matching searchTerm: String) async {
        burnVisitsMatchingSearchTermCalls.append(searchTerm)
    }

    func titles(for urls: [URL]) -> [URL : String] {
        titlesForURLsCalls.append(urls)
        return titlesForURLs(urls)
    }

    // swiftlint:disable:next identifier_name
    var _ranges: [DataModel.HistoryRange] = []
    var rangesCallCount: Int = 0
    var resetCacheCallCount: Int = 0

    var countVisibleVisitsForRangeCalls: [DataModel.HistoryRange] = []
    var countVisibleVisitsForRange: (DataModel.HistoryRange) async -> Int = { _ in return 0 }

    var countVisibleVisitsMatchingSearchTermCalls: [String] = []
    var countVisibleVisitsMatchingSearchTerm: (String) async -> Int = { _ in return 0 }

    var deleteVisitsForRangeCalls: [DataModel.HistoryRange] = []
    var burnVisitsForRangeCalls: [DataModel.HistoryRange] = []

    var deleteVisitsForIdentifierCalls: [[VisitIdentifier]] = []
    var burnVisitsForIdentifiersCalls: [[VisitIdentifier]] = []

    var deleteVisitsMatchingSearchTermCalls: [String] = []
    var burnVisitsMatchingSearchTermCalls: [String] = []

    var visitsBatchCalls: [VisitsBatchCall] = []
    var visitsBatch: (DataModel.HistoryQueryKind, Int, Int) async -> DataModel.HistoryItemsBatch = { _, _, _ in .init(finished: true, visits: []) }

    var titlesForURLsCalls: [[URL]] = []
    var titlesForURLs: ([URL]) -> [URL: String] = { _ in [:] }

    struct VisitsBatchCall: Equatable {
        let query: DataModel.HistoryQueryKind
        let limit: Int
        let offset: Int
    }
}

final class CapturingHistoryViewDeleteDialogPresenter: HistoryViewDeleteDialogPresenting {

    var response: HistoryViewDeleteDialogModel.Response = .noAction
    var showDialogCalls: [ShowDialogCall] = []

    struct ShowDialogCall: Equatable {
        let itemsCount: Int
        let deleteModel: HistoryViewDeleteDialogModel.DeleteMode

        init(_ itemsCount: Int, _ deleteModel: HistoryViewDeleteDialogModel.DeleteMode) {
            self.itemsCount = itemsCount
            self.deleteModel = deleteModel
        }
    }

    func showDialog(for itemsCount: Int, deleteMode: HistoryViewDeleteDialogModel.DeleteMode) async -> HistoryViewDeleteDialogModel.Response {
        showDialogCalls.append(.init(itemsCount, deleteMode))
        return response
    }
}

final class HistoryViewActionsHandlerTests: XCTestCase {

    var actionsHandler: HistoryViewActionsHandler!
    var dataProvider: CapturingHistoryViewDataProvider!
    var dialogPresenter: CapturingHistoryViewDeleteDialogPresenter!

    override func setUp() async throws {
        dataProvider = CapturingHistoryViewDataProvider()
        dialogPresenter = CapturingHistoryViewDeleteDialogPresenter()
        actionsHandler = HistoryViewActionsHandler(dataProvider: dataProvider, deleteDialogPresenter: dialogPresenter)
    }

    // MARK: - showDeleteDialog

    func testWhenDataProviderIsNilThenShowDeleteDialogReturnsNoAction() async {
        dataProvider = nil
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDataProviderHasNoVisitsForRangeThenShowDeleteDialogReturnsNoAction() async {
        dataProvider.countVisibleVisitsForRange = { _ in return 0 }
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dataProvider.deleteVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogIsCancelledThenShowDeleteDialogReturnsNoAction() async {
        dataProvider.countVisibleVisitsForRange = { _ in return 100 }
        dialogPresenter.response = .noAction
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dataProvider.deleteVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogReturnsUnknownResponseThenShowDeleteDialogReturnsNoAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisitsForRange = { _ in return 100 }
        dialogPresenter.response = .unknown
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dataProvider.deleteVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogIsAcceptedWithBurningThenShowDeleteDialogPerformsBurningAndReturnsDeleteAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisitsForRange = { _ in return 100 }
        dialogPresenter.response = .burn
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dataProvider.deleteVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsForRangeCalls.count, 1)
        XCTAssertEqual(dialogResponse, .delete)
    }

    func testWhenDeleteDialogIsAcceptedWithoutBurningThenShowDeleteDialogPerformsDeletiongAndReturnsDeleteAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisitsForRange = { _ in return 100 }
        dialogPresenter.response = .delete
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .all)
        XCTAssertEqual(dataProvider.deleteVisitsForRangeCalls.count, 1)
        XCTAssertEqual(dataProvider.burnVisitsForRangeCalls.count, 0)
        XCTAssertEqual(dialogResponse, .delete)
    }
}
