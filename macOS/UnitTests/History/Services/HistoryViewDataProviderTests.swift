//
//  HistoryViewDataProviderTests.swift
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

final class MockHistoryViewDateFormatter: HistoryViewDateFormatting {
    func currentDate() -> Date {
        date
    }

    func dayString(for date: Date) -> String {
        "Today"
    }

    func timeString(for date: Date) -> String {
        "10:08"
    }

    var date: Date = Date()
}

final class MockDomainFireproofStatusProvider: DomainFireproofStatusProviding {
    func isFireproof(fireproofDomain domain: String) -> Bool {
        isFireproof(domain)
    }

    var isFireproof: (String) -> Bool = { _ in false }
}

final class CapturingHistoryBurner: HistoryBurning {
    func burn(_ visits: [Visit], animated: Bool) async {
        burnCalls.append(.init(visits, animated))
    }

    var burnCalls: [BurnCall] = []

    struct BurnCall: Equatable {
        let visits: [Visit]
        let animated: Bool

        init(_ visits: [Visit], _ animated: Bool) {
            self.visits = visits
            self.animated = animated
        }
    }
}

final class HistoryViewDataProviderTests: XCTestCase {
    var provider: HistoryViewDataProvider!
    var dataSource: CapturingHistoryGroupingDataSource!
    var burner: CapturingHistoryBurner!
    var dateFormatter: MockHistoryViewDateFormatter!

    @MainActor
    override func setUp() async throws {
        dataSource = CapturingHistoryGroupingDataSource()
        burner = CapturingHistoryBurner()
        dateFormatter = MockHistoryViewDateFormatter()
        provider = HistoryViewDataProvider(historyGroupingDataSource: dataSource, historyBurner: burner, dateFormatter: dateFormatter)
        await provider.resetCache()
    }

    // MARK: - ranges

    func testThatRangesReturnsAllWhenHistoryIsEmpty() async {
        dataSource.history = nil
        await provider.resetCache()
        XCTAssertEqual(provider.ranges, [.all])

        dataSource.history = []
        await provider.resetCache()
        XCTAssertEqual(provider.ranges, [.all])
    }

    func testThatRangesIncludesTodayWhenHistoryContainsEntriesFromToday() async throws {
        let today = Date().startOfDay

        dataSource.history = [
            .make(url: try XCTUnwrap("https://example.com".url), visits: [
                .init(date: today.addingTimeInterval(10))
            ])
        ]
        await provider.resetCache()
        XCTAssertEqual(provider.ranges, [.all, .today])
    }

    func testThatRangesIncludesYesterdayWhenHistoryContainsEntriesFromYesterday() async throws {
        let today = Date().startOfDay

        dataSource.history = [
            .make(url: try XCTUnwrap("https://example.com".url), visits: [
                .init(date: today.addingTimeInterval(10)),
                .init(date: today.daysAgo(1))
            ])
        ]
        await provider.resetCache()
        XCTAssertEqual(provider.ranges, [.all, .today, .yesterday])
    }

    func testThatRangesIncludesOlderWhenHistoryContainsEntriesOlderThan5Days() async throws {
        let today = Date().startOfDay

        dataSource.history = [
            .make(url: try XCTUnwrap("https://example.com".url), visits: [
                .init(date: today.daysAgo(5))
            ])
        ]
        await provider.resetCache()
        XCTAssertEqual(provider.ranges, [.all, .older])
    }

    func testThatRangesIncludesNamedWeekdaysWhenHistoryContainsEntriesFrom2To4DaysAgo() async throws {
        func populateHistory(for date: Date) async throws {
            dateFormatter.date = date
            dataSource.history = [
                .make(url: try XCTUnwrap("https://example.com".url), visits: [
                    .init(date: dateFormatter.date.daysAgo(2)),
                    .init(date: dateFormatter.date.daysAgo(3)),
                    .init(date: dateFormatter.date.daysAgo(4))
                ])
            ]
            await provider.resetCache()
        }

        try await populateHistory(for: date(year: 2025, month: 2, day: 24)) // Monday
        XCTAssertEqual(provider.ranges, [.all, .saturday, .friday, .thursday])

        try await populateHistory(for: date(year: 2025, month: 2, day: 25)) // Tuesday
        XCTAssertEqual(provider.ranges, [.all, .sunday, .saturday, .friday])

        try await populateHistory(for: date(year: 2025, month: 2, day: 26)) // Wednesday
        XCTAssertEqual(provider.ranges, [.all, .monday, .sunday, .saturday])

        try await populateHistory(for: date(year: 2025, month: 2, day: 27)) // Thursday
        XCTAssertEqual(provider.ranges, [.all, .tuesday, .monday, .sunday])

        try await populateHistory(for: date(year: 2025, month: 2, day: 28)) // Friday
        XCTAssertEqual(provider.ranges, [.all, .wednesday, .tuesday, .monday])

        try await populateHistory(for: date(year: 2025, month: 3, day: 1)) // Saturday
        XCTAssertEqual(provider.ranges, [.all, .thursday, .wednesday, .tuesday])

        try await populateHistory(for: date(year: 2025, month: 3, day: 2)) // Sunday
        XCTAssertEqual(provider.ranges, [.all, .friday, .thursday, .wednesday])
    }

    private func date(year: Int?, month: Int?, day: Int?, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return try XCTUnwrap(Calendar.autoupdatingCurrent.date(from: components))
    }
}


fileprivate extension HistoryEntry {
    static func make(identifier: UUID = UUID(), url: URL, title: String? = nil, visits: Set<Visit>) -> HistoryEntry {
        let entry = HistoryEntry(
            identifier: identifier,
            url: url,
            title: title,
            failedToLoad: false,
            numberOfTotalVisits: visits.count,
            lastVisit: visits.map(\.date).max() ?? Date(),
            visits: [],
            numberOfTrackersBlocked: 0,
            blockedTrackingEntities: [],
            trackersFound: false
        )
        entry.visits = Set(visits.map {
            Visit(date: $0.date, identifier: entry.url, historyEntry: entry)
        })
        return entry
    }
}
