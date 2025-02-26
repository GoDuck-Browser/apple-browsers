//
//  SuggestionContainerTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Combine
import History
import NetworkingTestingUtils
import Suggestions
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class SuggestionContainerTests: XCTestCase {

    override class func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    func testWhenGetSuggestionsIsCalled_ThenContainerAsksAndHoldsSuggestionsFromLoader() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryProviderMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyProvider: historyCoordinatingMock,
                                                      bookmarkProvider: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        let e = expectation(description: "Suggestions updated")
        let cancellable = suggestionContainer.$result.sink {
            if $0 != nil {
                e.fulfill()
            }
        }

        suggestionContainer.getSuggestions(for: "test")
        let result = SuggestionResult.aSuggestionResult
        suggestionLoadingMock.completion!(result, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(suggestionContainer.result?.all, result.topHits + result.duckduckgoSuggestions + result.localSuggestions)
    }

    func testWhenStopGettingSuggestionsIsCalled_ThenNoSuggestionsArePublished() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryProviderMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyProvider: historyCoordinatingMock,
                                                      bookmarkProvider: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        suggestionContainer.getSuggestions(for: "test")
        suggestionContainer.stopGettingSuggestions()
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        XCTAssertNil(suggestionContainer.result)
    }

    func testSuggestionLoadingCacheClearing() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryProviderMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyProvider: historyCoordinatingMock,
                                                      bookmarkProvider: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)

        XCTAssertNil(suggestionContainer.suggestionDataCache)
        let e = expectation(description: "Suggestions updated")
        suggestionContainer.suggestionLoading(suggestionLoadingMock, suggestionDataFromUrl: URL.testsServer, withParameters: [:]) { data, error in
            XCTAssertNotNil(suggestionContainer.suggestionDataCache)
            e.fulfill()

            // Test the cache is not cleared if useCachedData is true
            XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)
            suggestionContainer.getSuggestions(for: "test", useCachedData: true)
            XCTAssertNotNil(suggestionContainer.suggestionDataCache)
            XCTAssert(suggestionLoadingMock.getSuggestionsCalled)

            suggestionLoadingMock.getSuggestionsCalled = false

            // Test the cache is cleared if useCachedData is false
            XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)
            suggestionContainer.getSuggestions(for: "test", useCachedData: false)
            XCTAssertNil(suggestionContainer.suggestionDataCache)
            XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        }

        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testSuggestionsJsonScenarios() async throws {
        guard let directoryURL = Bundle(for: SuggestionContainerTests.self).url(forResource: "privacy-reference-tests/suggestions", withExtension: nil) else {
            return XCTFail("Failed to locate the suggestions directory in the bundle")
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

        // Filter for JSON files
        let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }

        for fileURL in jsonFiles {
            // Load and decode each JSON file
            let data = try Data(contentsOf: fileURL)
            let testScenario: TestScenario
            do {
                testScenario = try JSONDecoder().decode(TestScenario.self, from: data)
            } catch let error as NSError {
                throw NSError(domain: error.domain, code: error.code, userInfo: error.userInfo.merging([NSFilePathErrorKey: fileURL.lastPathComponent]) { $1 })
            }

            // Run the test for each scenario
            try await runJsonTestScenario(testScenario, named: fileURL.deletingPathExtension().lastPathComponent)
        }
    }

    @MainActor
    private func runJsonTestScenario(_ testScenario: TestScenario, named name: String) async throws {
        let input = testScenario.input

        // Create tab collection view models for open and burner tabs
        let tabCollectionViewModels = input.windows.map { window in
            TabCollectionViewModel(tabCollection: tabCollection(window.tabs.map(OpenTab.init)),
                                   selectionIndex: window.selectedTab.type == .pinned ? .pinned(window.selectedTab.index) : .unpinned(window.selectedTab.index),
                                   burnerMode: .regular)
        }
        // Index of the window that is currently selected.
        let selectedWindowIndices = input.windows.enumerated().filter { $0.element.isSelected }.map(\.offset)
        guard selectedWindowIndices.count == 1 else { return XCTFail("Multiple selected windows are not supported: \(selectedWindowIndices)") }
        let selectedWindow = selectedWindowIndices[0]

        // Initialize a mock WindowControllersManager with pinned tabs, tab view models, and the selected window index for testing.
        let windowControllersManagerMock = WindowControllersManagerMock(pinnedTabsManager: pinnedTabsManager(tabs: input.pinnedTabs),
                                                                        tabCollectionViewModels: tabCollectionViewModels,
                                                                        selectedWindow: selectedWindow)

        // Tested object
        let suggestionContainer = SuggestionContainer(urlSession: .mock(),
                                                      historyProvider: HistoryProviderMock(history: input.history),
                                                      bookmarkProvider: BookmarkProviderMock(bookmarks: input.bookmarks),
                                                      burnerMode: tabCollectionViewModels[selectedWindow].burnerMode,
                                                      windowControllersManager: windowControllersManagerMock)

        // Mock API Suggestions response
        MockURLProtocol.requestHandler = { request in
            let urlComponents = URLComponents(string: request.url!.absoluteString)!
            XCTAssertTrue(urlComponents.queryItems!.contains(URLQueryItem(name: "q", value: input.query)))
            switch input.apiSuggestions {
            case .suggestions(let suggestions):
                var respData: Data?
                do {
                    respData = try JSONEncoder().encode(suggestions)
                } catch {
                    XCTFail("Could not encode API suggestions from \(name) to JSON: \(error)")
                }
                return (HTTPURLResponse.ok, respData)
            case .error(let error):
                return (HTTPURLResponse(url: request.url!,
                                        statusCode: error.statusCode,
                                        httpVersion: nil,
                                        headerFields: [:])!, nil)
            }
        }

        // Get the compiled suggestions
        let resultPromise = suggestionContainer.$result.dropFirst().timeout(1).first().promise()
        suggestionContainer.getSuggestions(for: input.query)
        let result = try await resultPromise.get()

        XCTAssertEqual(result, testScenario.expectation, "Incorrect results for \(name)")
    }

}

extension SuggestionContainerTests {

    struct TestScenario: Decodable {
        let description: String
        let input: TestInput
        let expectation: SuggestionResult
    }

    struct TestInput: Decodable {
        let query: String
        let bookmarks: [Bookmark]
        let history: [HistoryEntry]
        let pinnedTabs: [OpenTab]
        let windows: [Window]
        let apiSuggestions: ApiSuggestions

        enum ApiSuggestions: Decodable {
            case suggestions([Suggestions.APIResult.SuggestionResult])
            case error(HTTPError)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let result = try? container.decode(Suggestions.APIResult.self) {
                    self = .suggestions(result.items)
                } else {
                    self = try .error(.init(from: decoder))
                }
            }
        }
        struct HTTPError: Swift.Error, Decodable {
            let statusCode: Int
        }
    }

    struct Bookmark: Decodable, Suggestions.Bookmark {
        let title: String
        let url: String
        let isFavorite: Bool
    }

    struct HistoryEntry: Decodable, Suggestions.HistorySuggestion {
        var identifier: UUID
        var title: String?
        let url: URL
        let numberOfVisits: Int
        var lastVisit: Date
        var failedToLoad: Bool
    }

    struct Window: Decodable {
        enum WindowType: String, Decodable {
            case regular
            case fire
            case popup
        }
        struct SelectedTab: Decodable {
            enum TabType: String, Decodable {
                case pinned
                case regular
            }
            let type: TabType
            let index: Int
        }
        let type: String
        private let selected: Bool?
        var isSelected: Bool { selected ?? false }
        let selectedTab: SelectedTab
        let tabs: [TabMock]
    }

    struct TabMock: Decodable {
        let title: String
        let url: URL
    }

    struct APISuggestion: Decodable {
        let phrase: String
        let isNav: Bool?
    }

    class WindowControllersManagerMock: WindowControllersManagerProtocol {
        var mainWindowControllers: [DuckDuckGo_Privacy_Browser.MainWindowController] = []

        var lastKeyMainWindowController: DuckDuckGo_Privacy_Browser.MainWindowController?

        var pinnedTabsManager: DuckDuckGo_Privacy_Browser.PinnedTabsManager

        var didRegisterWindowController = PassthroughSubject<(DuckDuckGo_Privacy_Browser.MainWindowController), Never>()

        var didUnregisterWindowController = PassthroughSubject<(DuckDuckGo_Privacy_Browser.MainWindowController), Never>()

        func register(_ windowController: DuckDuckGo_Privacy_Browser.MainWindowController) {
        }

        func unregister(_ windowController: DuckDuckGo_Privacy_Browser.MainWindowController) {
        }

        func show(url: URL?, source: DuckDuckGo_Privacy_Browser.Tab.TabContent.URLSource, newTab: Bool) {
        }

        func showBookmarksTab() {
        }

        func showTab(with content: DuckDuckGo_Privacy_Browser.Tab.TabContent) {
        }

        var allTabCollectionViewModels: [TabCollectionViewModel] = []
        var selectedWindowIndex: Int
        var selectedTab: Tab?

        func openNewWindow(with tabCollectionViewModel: DuckDuckGo_Privacy_Browser.TabCollectionViewModel?, burnerMode: DuckDuckGo_Privacy_Browser.BurnerMode, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool, lazyLoadTabs: Bool, isMiniaturized: Bool, isMaximized: Bool, isFullscreen: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
            nil
        }

        init(pinnedTabsManager: PinnedTabsManager, tabCollectionViewModels: [TabCollectionViewModel] = [], selectedWindow: Int = 0) {
            self.pinnedTabsManager = pinnedTabsManager
            self.allTabCollectionViewModels = tabCollectionViewModels
            self.selectedWindowIndex = selectedWindow
        }
    }

    @MainActor
    private func tabCollection(_ openTabs: [OpenTab], burnerMode: BurnerMode = .regular) -> TabCollection {
        let tabs = openTabs.map {
            Tab(content: TabContent.contentFromURL($0.url, source: .link), title: $0.title, burnerMode: burnerMode)
        }
        return TabCollection(tabs: tabs)
    }

    @MainActor
    private func pinnedTabsManager(tabs: [OpenTab]) -> PinnedTabsManager {
        PinnedTabsManager(tabCollection: tabCollection(tabs))
    }

}
private extension OpenTab {
    init(_ tab: SuggestionContainerTests.TabMock) {
        self.init(title: tab.title, url: tab.url)
    }
}
class HistoryProviderMock: SuggestionContainer.HistoryProvider {
    let history: [SuggestionContainerTests.HistoryEntry]

    func history(for suggestionLoading: any Suggestions.SuggestionLoading) -> [any Suggestions.HistorySuggestion] {
        history
    }

    init(history: [SuggestionContainerTests.HistoryEntry] = []) {
        self.history = history
    }
}
private class BookmarkProviderMock: SuggestionContainer.BookmarkProvider {
    let bookmarks: [SuggestionContainerTests.Bookmark]
    
    func bookmarks(for suggestionLoading: any Suggestions.SuggestionLoading) -> [any Suggestions.Bookmark] {
        bookmarks
    }
    
    init(bookmarks: [SuggestionContainerTests.Bookmark]) {
        self.bookmarks = bookmarks
    }
}

extension Suggestion: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type, phrase, url, title, isFavorite, numberOfVisits, value
    }

    private enum SuggestionType: String, Decodable {
        case phrase
        case website
        case bookmark
        case historyEntry
        case internalPage
        case openTab
        case unknown
    }

    private enum DecodingError: Error {
        case invalidType(String)
        case invalidBookmark(SuggestionContainerTests.Bookmark)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch SuggestionType(rawValue: type) {
        case .phrase:
            let phrase = try container.decode(String.self, forKey: .phrase)
            self = .phrase(phrase: phrase)
        case .website:
            let url = try container.decode(URL.self, forKey: .url)
            self = .website(url: url)
        case .bookmark:
            let title = try container.decode(String.self, forKey: .title)
            let url = try container.decode(String.self, forKey: .url)
            let isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
            let bookmark = SuggestionContainerTests.Bookmark(title: title, url: url, isFavorite: isFavorite)
            self = try .init(bookmark: bookmark) ?? { throw DecodingError.invalidBookmark(bookmark) }()
        case .historyEntry:
            let title = try container.decode(String.self, forKey: .title)
            let url = try container.decode(URL.self, forKey: .url)
            let numberOfVisits = try container.decode(Int.self, forKey: .numberOfVisits)
            self = .init(historyEntry: SuggestionContainerTests.HistoryEntry(identifier: UUID(), title: title, url: url, numberOfVisits: numberOfVisits, lastVisit: Date(), failedToLoad: false))
        case .internalPage:
            let title = try container.decode(String.self, forKey: .title)
            let url = try container.decode(URL.self, forKey: .url)
            self = .internalPage(title: title, url: url)
        case .openTab:
            let title = try container.decode(String.self, forKey: .title)
            let url = try container.decode(URL.self, forKey: .url)
            self = .openTab(title: title, url: url)
        case .unknown:
            let value = try container.decode(String.self, forKey: .value)
            self = .unknown(value: value)
        default:
            throw DecodingError.invalidType(type)
        }
    }
}
extension SuggestionResult: Decodable {
    public init(from decoder: any Decoder) throws {
        struct TestExpectation: Decodable {
            let topHits: [Suggestion]
            let duckduckgoSuggestions: [Suggestion]
            let localSuggestions: [Suggestion]
        }
        let result = try TestExpectation(from: decoder)
        self.init(topHits: result.topHits, duckduckgoSuggestions: result.duckduckgoSuggestions, localSuggestions: result.localSuggestions)
    }
}
private extension URLSession {
    static func mock() -> URLSession {
        let testConfiguration = URLSessionConfiguration.default
        testConfiguration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: testConfiguration)
    }
}
