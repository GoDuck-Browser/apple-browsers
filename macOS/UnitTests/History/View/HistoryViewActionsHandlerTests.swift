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

    func deleteVisits(for identifiers: [VisitIdentifier]) async {
        deleteVisitsForIdentifierCalls.append(identifiers)
    }

    func burnVisits(for identifiers: [VisitIdentifier]) async {
        burnVisitsForIdentifiersCalls.append(identifiers)
    }

    func countVisibleVisits(matching query: DataModel.HistoryQueryKind) async -> Int {
        countVisibleVisitsCalls.append(query)
        return await countVisibleVisits(query)
    }

    func deleteVisits(matching query: DataModel.HistoryQueryKind) async {
        deleteVisitsMatchingQueryCalls.append(query)
    }

    func burnVisits(matching query: DataModel.HistoryQueryKind) async {
        burnVisitsMatchingQueryCalls.append(query)
    }


    func titles(for urls: [URL]) -> [URL : String] {
        titlesForURLsCalls.append(urls)
        return titlesForURLs(urls)
    }

    // swiftlint:disable:next identifier_name
    var _ranges: [DataModel.HistoryRange] = []
    var rangesCallCount: Int = 0
    var resetCacheCallCount: Int = 0

    var countVisibleVisitsCalls: [DataModel.HistoryQueryKind] = []
    var countVisibleVisits: (DataModel.HistoryQueryKind) async -> Int = { _ in return 0 }

    var deleteVisitsMatchingQueryCalls: [DataModel.HistoryQueryKind] = []
    var burnVisitsMatchingQueryCalls: [DataModel.HistoryQueryKind] = []

    var deleteVisitsForIdentifierCalls: [[VisitIdentifier]] = []
    var burnVisitsForIdentifiersCalls: [[VisitIdentifier]] = []

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

final class CapturingHistoryViewDeleteDialogPresenter: HistoryViewDialogPresenting {

    var multipleTabsDialogResponse: OpenMultipleTabsWarningDialogModel.Response = .cancel
    var showMultipleTabsDialogCalls: [Int] = []

    var deleteDialogResponse: HistoryViewDeleteDialogModel.Response = .noAction
    var showDeleteDialogCalls: [ShowDialogCall] = []

    struct ShowDialogCall: Equatable {
        let itemsCount: Int
        let deleteModel: HistoryViewDeleteDialogModel.DeleteMode

        init(_ itemsCount: Int, _ deleteModel: HistoryViewDeleteDialogModel.DeleteMode) {
            self.itemsCount = itemsCount
            self.deleteModel = deleteModel
        }
    }

    func showDeleteDialog(for itemsCount: Int, deleteMode: HistoryViewDeleteDialogModel.DeleteMode) async -> HistoryViewDeleteDialogModel.Response {
        showDeleteDialogCalls.append(.init(itemsCount, deleteMode))
        return deleteDialogResponse
    }

    func showMultipleTabsDialog(for itemsCount: Int) async -> OpenMultipleTabsWarningDialogModel.Response {
        showMultipleTabsDialogCalls.append(itemsCount)
        return multipleTabsDialogResponse
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
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDataProviderHasNoVisitsForRangeThenShowDeleteDialogReturnsNoAction() async {
        dataProvider.countVisibleVisits = { _ in return 0 }
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dataProvider.deleteVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogIsCancelledThenShowDeleteDialogReturnsNoAction() async {
        dataProvider.countVisibleVisits = { _ in return 100 }
        dialogPresenter.deleteDialogResponse = .noAction
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dataProvider.deleteVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogReturnsUnknownResponseThenShowDeleteDialogReturnsNoAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisits = { _ in return 100 }
        dialogPresenter.deleteDialogResponse = .unknown
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dataProvider.deleteVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dialogResponse, .noAction)
    }

    func testWhenDeleteDialogIsAcceptedWithBurningThenShowDeleteDialogPerformsBurningAndReturnsDeleteAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisits = { _ in return 100 }
        dialogPresenter.deleteDialogResponse = .burn
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dataProvider.deleteVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dataProvider.burnVisitsMatchingQueryCalls.count, 1)
        XCTAssertEqual(dialogResponse, .delete)
    }

    func testWhenDeleteDialogIsAcceptedWithoutBurningThenShowDeleteDialogPerformsDeletiongAndReturnsDeleteAction() async {
        // this scenario shouldn't happen in real life anyway but is included for completeness
        dataProvider.countVisibleVisits = { _ in return 100 }
        dialogPresenter.deleteDialogResponse = .delete
        let dialogResponse = await actionsHandler.showDeleteDialog(for: .rangeFilter(.all))
        XCTAssertEqual(dataProvider.deleteVisitsMatchingQueryCalls.count, 1)
        XCTAssertEqual(dataProvider.burnVisitsMatchingQueryCalls.count, 0)
        XCTAssertEqual(dialogResponse, .delete)
    }
}
