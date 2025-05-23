//
//  CapturingDataProvider.swift
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

import HistoryView

final class CapturingDataProvider: DataProviding {

    var ranges: [DataModel.HistoryRangeWithCount] {
        rangesCallCount += 1
        return _ranges
    }

    func refreshData() {
        refreshDataCallCount += 1
    }

    func visitsBatch(for query: DataModel.HistoryQueryKind, source: DataModel.HistoryQuerySource, limit: Int, offset: Int) async -> DataModel.HistoryItemsBatch {
        visitsBatchCalls.append(.init(query: query, source: source, limit: limit, offset: offset))
        return await visitsBatch(query, source, limit, offset)
    }

    func countVisibleVisits(for range: DataModel.HistoryRange) async -> Int {
        countVisibleVisitsCalls.append(range)
        return await countVisibleVisits(range)
    }

    func deleteVisits(matching query: DataModel.HistoryQueryKind) async {
        deleteVisitsCalls.append(query)
    }

    func burnVisits(matching query: DataModel.HistoryQueryKind) async {
        burnVisitsCalls.append(query)
    }

    // swiftlint:disable:next identifier_name
    var _ranges: [DataModel.HistoryRangeWithCount] = []
    var rangesCallCount: Int = 0
    var refreshDataCallCount: Int = 0

    var countVisibleVisitsCalls: [DataModel.HistoryRange] = []
    var countVisibleVisits: (DataModel.HistoryRange) async -> Int = { _ in return 0 }

    var deleteVisitsCalls: [DataModel.HistoryQueryKind] = []
    var burnVisitsCalls: [DataModel.HistoryQueryKind] = []

    var visitsBatchCalls: [VisitsBatchCall] = []
    var visitsBatch: (DataModel.HistoryQueryKind, DataModel.HistoryQuerySource, Int, Int) async -> DataModel.HistoryItemsBatch = { _, _, _, _ in .init(finished: true, visits: []) }

    struct VisitsBatchCall: Equatable {
        let query: DataModel.HistoryQueryKind
        let source: DataModel.HistoryQuerySource
        let limit: Int
        let offset: Int
    }
}
