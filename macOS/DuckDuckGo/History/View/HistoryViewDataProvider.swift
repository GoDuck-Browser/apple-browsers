//
//  HistoryViewDataProvider.swift
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

import BrowserServicesKit
import Foundation
import History
import HistoryView

protocol HistoryDeleting: AnyObject {
    func delete(_ visits: [Visit]) async
}

protocol HistoryDataSource: HistoryGroupingDataSource, HistoryDeleting {
    var historyDictionary: [URL: HistoryEntry]? { get }
}

extension HistoryCoordinator: HistoryDataSource {
    func delete(_ visits: [Visit]) async {
        await withCheckedContinuation { continuation in
            burnVisits(visits) {
                continuation.resume()
            }
        }
    }
}

protocol HistoryBurning: AnyObject {
    func burn(_ visits: [Visit], animated: Bool) async
}

final class FireHistoryBurner: HistoryBurning {
    let fireproofDomains: DomainFireproofStatusProviding
    let fire: () async -> Fire

    init(fireproofDomains: DomainFireproofStatusProviding = FireproofDomains.shared, fire: (() async -> Fire)? = nil) {
        self.fireproofDomains = fireproofDomains
        self.fire = fire ?? { @MainActor in FireCoordinator.fireViewModel.fire }
    }

    func burn(_ visits: [Visit], animated: Bool) async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                await fire().burnVisits(visits, except: fireproofDomains, isToday: animated) {
                    continuation.resume()
                }
            }
        }
    }
}

struct HistoryViewGrouping {
    let range: DataModel.HistoryRange
    let items: [DataModel.HistoryItem]

    init(range: DataModel.HistoryRange, visits: [DataModel.HistoryItem]) {
        self.range = range
        self.items = visits
    }

    init?(_ historyGrouping: HistoryGrouping, dateFormatter: HistoryViewDateFormatting) {
        guard let range = DataModel.HistoryRange(date: historyGrouping.date, referenceDate: dateFormatter.currentDate()) else {
            return nil
        }
        self.range = range
        items = historyGrouping.visits.compactMap { DataModel.HistoryItem($0, dateFormatter: dateFormatter) }
    }
}

protocol HistoryViewDataProviding: HistoryView.DataProviding {

    func titles(for urls: [URL]) -> [URL: String]

    func countVisibleVisits(for range: DataModel.HistoryRange) async -> Int
    func deleteVisits(for identifiers: [VisitIdentifier]) async
    func burnVisits(for identifiers: [VisitIdentifier]) async

    func countVisibleVisits(matching searchTerm: String) async -> Int
    func deleteVisits(matching searchTerm: String) async
    func burnVisits(matching searchTerm: String) async
}

final class HistoryViewDataProvider: HistoryViewDataProviding {

    init(
        historyDataSource: HistoryDataSource,
        historyBurner: HistoryBurning = FireHistoryBurner(),
        dateFormatter: HistoryViewDateFormatting = DefaultHistoryViewDateFormatter(),
        featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger
    ) {
        self.dateFormatter = dateFormatter
        self.historyDataSource = historyDataSource
        self.historyBurner = historyBurner
        historyGroupingProvider = HistoryGroupingProvider(dataSource: historyDataSource, featureFlagger: featureFlagger)
    }

    var ranges: [DataModel.HistoryRange] {
        var ranges: [DataModel.HistoryRange] = [.all]
        ranges.append(contentsOf: groupings.map(\.range))
        return ranges
    }

    func refreshData() async {
        lastQuery = nil
        await populateVisits()
    }

    func visitsBatch(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> HistoryView.DataModel.HistoryItemsBatch {
        let items = perform(query)
        let visits = items.chunk(with: limit, offset: offset)
        let finished = offset + limit >= items.count
        return DataModel.HistoryItemsBatch(finished: finished, visits: visits)
    }

    func countVisibleVisits(for range: DataModel.HistoryRange) async -> Int {
        guard range != .all else {
            return historyItems.count
        }
        return groupings.first(where: { $0.range == range })?.items.count ?? 0
    }

    func deleteVisits(for range: DataModel.HistoryRange) async {
        let visits = await allVisits(for: range)
        await historyDataSource.delete(visits)
        await refreshData()
    }

    func burnVisits(for range: DataModel.HistoryRange) async {
        let visits = await allVisits(for: range)
        let animated = range == .today || range == .all
        await historyBurner.burn(visits, animated: animated)
        await refreshData()
    }

    func deleteVisits(for identifiers: [VisitIdentifier]) async {
        let visits = await visits(for: identifiers)
        await historyDataSource.delete(visits)
        await refreshData()
    }

    func burnVisits(for identifiers: [VisitIdentifier]) async {
        let visits = await visits(for: identifiers)
        await historyBurner.burn(visits, animated: false)
        await refreshData()
    }

    func countVisibleVisits(matching searchTerm: String) async -> Int {
        guard let lastQuery, lastQuery.query == .searchTerm(searchTerm) else {
            let items = perform(.searchTerm(searchTerm))
            return items.count
        }
        return lastQuery.items.count
    }

    func deleteVisits(matching searchTerm: String) async {
        let visits = await allVisits(matching: searchTerm)
        await historyDataSource.delete(visits)
        await refreshData()
    }

    func burnVisits(matching searchTerm: String) async {
        let visits = await allVisits(matching: searchTerm)
        await historyBurner.burn(visits, animated: false)
        await refreshData()
    }

    func titles(for urls: [URL]) -> [URL: String] {
        guard let historyDictionary = historyDataSource.historyDictionary else {
            return [:]
        }

        return urls.reduce(into: [URL: String]()) { partialResult, url in
            partialResult[url] = historyDictionary[url]?.title
        }
    }

    // MARK: - Private

    @MainActor
    private func populateVisits() {
        var olderHistoryItems = [DataModel.HistoryItem]()
        var olderVisits = [Visit]()

        // generate groupings by day and set aside "older" days.
        groupings = historyGroupingProvider.getVisitGroupings()
            .compactMap { historyGrouping -> HistoryViewGrouping? in
                guard let grouping = HistoryViewGrouping(historyGrouping, dateFormatter: dateFormatter) else {
                    return nil
                }
                guard grouping.range != .older else {
                    olderHistoryItems.append(contentsOf: grouping.items)
                    olderVisits.append(contentsOf: historyGrouping.visits)
                    return nil
                }
                visitsByRange[grouping.range] = historyGrouping.visits
                return grouping
            }

        // collect all "older" days into a single grouping
        if !olderHistoryItems.isEmpty {
            groupings.append(.init(range: .older, visits: olderHistoryItems))
        }
        if !olderVisits.isEmpty {
            visitsByRange[.older] = olderVisits
        }

        self.historyItems = groupings.flatMap(\.items)
    }

    private func allVisits(for range: DataModel.HistoryRange) async -> [Visit] {
        guard let history = await fetchHistory() else {
            return []
        }
        let date = lastQuery?.date ?? dateFormatter.currentDate()

        let allVisits: [Visit] = history.flatMap(\.visits)
        guard let dateRange = range.dateRange(for: date) else {
            return allVisits
        }
        return allVisits.filter { dateRange.contains($0.date) }
    }

    private func allVisits(matching searchTerm: String) async -> [Visit] {
        guard let history = await fetchHistory() else {
            return []
        }

        return history.reduce(into: [Visit]()) { partialResult, historyEntry in
            if historyEntry.matches(searchTerm) {
                partialResult.append(contentsOf: historyEntry.visits)
            }
        }
    }

    private func visits(for identifiers: [VisitIdentifier]) async -> [Visit] {
        guard let historyDictionary = historyDataSource.historyDictionary else {
            return []
        }

        return identifiers.reduce(into: [Visit]()) { partialResult, identifier in
            guard let visitsForIdentifier = historyDictionary[identifier.url]?.visits else {
                return
            }
            let visitsMatchingDay = visitsForIdentifier.filter { $0.date.isSameDay(identifier.date) }
            partialResult.append(contentsOf: visitsMatchingDay)
        }
    }

    /**
     * This function is here to ensure that history is accessed on the main thread.
     *
     * `HistoryCoordinator` uses `dispatchPrecondition(condition: .onQueue(.main))` internally.
     */
    @MainActor
    private func fetchHistory() async -> BrowsingHistory? {
        historyDataSource.history
    }

    private func perform(_ query: DataModel.HistoryQueryKind) -> [DataModel.HistoryItem] {
        if let lastQuery, lastQuery.query == query {
            return lastQuery.items
        }

        let items: [DataModel.HistoryItem] = {
            switch query {
            case .rangeFilter(.all), .searchTerm(""), .domainFilter(""):
                return historyItems
            case .rangeFilter(let range):
                return groupings.first(where: { $0.range == range })?.items ?? []
            case .searchTerm(let term):
                return historyItems.filter { $0.matches(term) }
            case .domainFilter(let domain):
                return historyItems.filter { $0.etldPlusOne == domain }
            }
        }()

        lastQuery = .init(date: dateFormatter.currentDate(), query: query, items: items)
        return items
    }

    private let historyGroupingProvider: HistoryGroupingProvider
    private let historyDataSource: HistoryDataSource
    private let dateFormatter: HistoryViewDateFormatting
    private let historyBurner: HistoryBurning

    /// this is to be optimized: https://app.asana.com/0/72649045549333/1209339909309306
    private var groupings: [HistoryViewGrouping] = []
    private var historyItems: [DataModel.HistoryItem] = []

    private var visitsByRange: [DataModel.HistoryRange: [Visit]] = [:]

    private struct QueryInfo {
        /// When the query happened.
        let date: Date
        /// What was the query.
        let query: DataModel.HistoryQueryKind
        /// Query result (a subset of `HistoryViewDataProvider.historyItems`)
        let items: [DataModel.HistoryItem]
    }

    /// The last query from the FE, i.e. filtered items list.
    private var lastQuery: QueryInfo?
}

protocol SearchableHistoryEntry {
    func matches(_ searchTerm: String) -> Bool
}

extension HistoryEntry: SearchableHistoryEntry {
    func matches(_ searchTerm: String) -> Bool {
        (title ?? "").localizedCaseInsensitiveContains(searchTerm) || url.absoluteString.localizedCaseInsensitiveContains(searchTerm)
    }
}

extension HistoryView.DataModel.HistoryItem: SearchableHistoryEntry {
    func matches(_ searchTerm: String) -> Bool {
        title.localizedCaseInsensitiveContains(searchTerm) || url.localizedCaseInsensitiveContains(searchTerm)
    }
}

extension HistoryView.DataModel.HistoryItem {
    /**
     * This initializer converts native side history `Visit` into FE `HistoryItem` model.
     *
     * It uses a date formatter because `HistoryItem` models are dumb and are expected
     * to contain user-visible text instead of timestamps.
     */
    init?(_ visit: Visit, dateFormatter: HistoryViewDateFormatting) {
        guard let historyEntry = visit.historyEntry else {
            return nil
        }
        let title: String = {
            guard let title = historyEntry.title, !title.isEmpty else {
                return historyEntry.url.absoluteString
            }
            return title
        }()

        let favicon: DataModel.Favicon? = {
            guard let url = visit.historyEntry?.url, let src = URL.duckFavicon(for: url)?.absoluteString else {
                return nil
            }
            return .init(maxAvailableSize: Int(Favicon.SizeCategory.small.rawValue), src: src)
        }()

        self.init(
            id: VisitIdentifier(historyEntry: historyEntry, date: visit.date).description,
            url: historyEntry.url.absoluteString,
            title: title,
            domain: historyEntry.url.host ?? historyEntry.url.absoluteString,
            etldPlusOne: historyEntry.etldPlusOne,
            dateRelativeDay: dateFormatter.dayString(for: visit.date),
            dateShort: "", // not in use at the moment
            dateTimeOfDay: dateFormatter.timeString(for: visit.date),
            favicon: favicon
        )
    }
}

struct VisitIdentifier: LosslessStringConvertible {
    init?(_ description: String) {
        let components = description.components(separatedBy: "|")
        guard components.count == 3, let url = components[1].url, let date = Self.timestampFormatter.date(from: components[2]) else {
            return nil
        }
        self.init(uuid: components[0], url: url, date: date)
    }

    init(historyEntry: HistoryEntry, date: Date) {
        self.uuid = historyEntry.identifier.uuidString
        self.url = historyEntry.url
        self.date = date
    }

    init(uuid: String, url: URL, date: Date) {
        self.uuid = uuid
        self.url = url
        self.date = date
    }

    var description: String {
        [uuid, url.absoluteString, Self.timestampFormatter.string(from: date)].joined(separator: "|")
    }

    let uuid: String
    let url: URL
    let date: Date

    static let timestampFormatter = ISO8601DateFormatter()
}
