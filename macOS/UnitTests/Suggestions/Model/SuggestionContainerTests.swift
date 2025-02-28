//
//  SuggestionContainerTests.swift
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

import Combine
import History
import NetworkingTestingUtils
import SnapshotTesting
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
        let jsonFiles = fileURLs.filter {
            $0.pathExtension == "json"
            && !$0.deletingPathExtension().lastPathComponent.hasSuffix("schema")
        }

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

        // Find window and index containing the tab initiating the search
        var selectedWindow = 0
        var selectedTabIndex: TabIndex?

        // Search windows for tab initiating search
        for (windowIndex, window) in input.windows.enumerated() {
            if let tabIndex = window.tabs.firstIndex(where: { $0.tabId == input.tabIdInitiatingSearch }) {
                selectedWindow = windowIndex
                selectedTabIndex = .unpinned(tabIndex)
                break
            }
        }
        // Index of the tab that is currently selected.
        if selectedTabIndex == nil, let pinnedTabIndex = input.pinnedTabs.firstIndex(where: { $0.tabId == input.tabIdInitiatingSearch }) {
            selectedTabIndex = .pinned(pinnedTabIndex)
        }
        guard let selectedTabIndex else { return XCTFail("Selected Tab Id not found") }

        // Create tab collection view models for each window
        let tabCollectionViewModels = input.windows.enumerated().map { (idx, window) in
            let burnerMode = window.type == .fire ? BurnerMode(isBurner: true) : BurnerMode.regular
            return TabCollectionViewModel(
                tabCollection: tabCollection(window.tabs.map(OpenTab.init), burnerMode: burnerMode),
                selectionIndex: idx == selectedWindow ? selectedTabIndex : .unpinned(0),
                burnerMode: burnerMode
            )
        }


        // Initialize a mock WindowControllersManager with pinned tabs, tab view models, and the selected window index for testing.
        let windowControllersManagerMock = WindowControllersManagerMock(pinnedTabsManager: pinnedTabsManager(tabs: input.pinnedTabs.map(OpenTab.init)),
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
        let actualResult = try await resultPromise.get()

        assert(TestExpectations(actualResult, query: testScenario.input.query, windows: testScenario.input.windows), named: name, matches: testScenario.expectations)
    }

}

extension SuggestionContainerTests {

    fileprivate struct TestScenario: Decodable {
        let description: String
        let input: TestInput
        let expectations: TestExpectations
    }

    struct TestInput: Decodable {
        let query: String
        let tabIdInitiatingSearch: UUID
        let bookmarks: [Bookmark]
        let history: [HistoryEntry]
        let pinnedTabs: [TabMock]
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
        // Window types from schema
        enum WindowType: String, Decodable {
            case regular = "fullyFeatured"
            case fire = "fireWindow"
            case popup
        }

        // Only fields defined in schema
        let type: WindowType
        let tabs: [TabMock]
    }

    // Update TabMock to match schema
    struct TabMock: Equatable, Decodable {
        let tabId: UUID
        let title: String
        let url: URL

        private enum CodingKeys: String, CodingKey {
            case tabId, title, uri
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.tabId = try container.decode(UUID.self, forKey: .tabId)
            self.title = try container.decode(String.self, forKey: .title)
            self.url = try container.decode(URL.self, forKey: .uri)
        }
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
        let contentBlockingMock = ContentBlockingMock()
        let privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        (contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration).isFeatureKeyEnabled = { _, _ in
            return false
        }
        let tabs = openTabs.map {
            Tab(content: TabContent.contentFromURL($0.url, source: .link), webViewConfiguration: WKWebViewConfiguration(), privacyFeatures: privacyFeaturesMock, title: $0.title, burnerMode: burnerMode)
        }
        return TabCollection(tabs: tabs)
    }

    @MainActor
    private func pinnedTabsManager(tabs: [OpenTab]) -> PinnedTabsManager {
        PinnedTabsManager(tabCollection: tabCollection(tabs))
    }

    func assert<Value: Encodable>(
      _ value: @autoclosure () throws -> Value,
      named name: String,
      matches anotherValue: Value,
      file: StaticString = #file,
      testName: String = #function,
      line: UInt = #line
    ) {
        let snapshotDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("temp_snapshots")
        let identifier = sanitizePathComponent(name)
        let testName = sanitizePathComponent(testName)
        let fileName = "\(testName).\(identifier).json"
        let snapshotUrl = snapshotDirectory.appendingPathComponent(fileName)
        let failure = verifySnapshot(of: try {
            try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
            // write anotherValue to the snapshot dir
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(anotherValue).write(to: snapshotUrl)
            return try value()
        }(), as: .json, named: name, record: false, snapshotDirectory: snapshotDirectory.path, timeout: 0, file: file, testName: testName)
        defer {
            try? FileManager.default.removeItem(at: snapshotUrl)
        }
        guard let message = failure else { return }
        XCTFail(message, file: file, line: line)
    }
    func sanitizePathComponent(_ string: String) -> String {
      return
        string
        .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
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

extension SuggestionContainerTests {
    fileprivate struct TestExpectations: Codable {
        struct ExpectedSuggestion: Codable {
            enum SuggestionType: String, Codable {
                case phrase
                case website
                case bookmark
                case favorite
                case historyEntry
                case openTab
                case internalPage
            }

            let type: SuggestionType
            let title: String
            let subtitle: String
            let uri: String?
            let tabId: UUID?
            let score: Int
        }

        let topHits: [ExpectedSuggestion]
        let searchSuggestions: [ExpectedSuggestion]
        let localSuggestions: [ExpectedSuggestion]

        init?(_ result: SuggestionResult?, query: String, windows: [SuggestionContainerTests.Window]) {
            guard let result else { return nil }
            self.topHits = result.topHits.compactMap { $0.expectedSuggestion(query: query, windows: windows) }
            self.searchSuggestions = result.duckduckgoSuggestions.compactMap { $0.expectedSuggestion(query: query, windows: windows) }
            self.localSuggestions = result.localSuggestions.compactMap { $0.expectedSuggestion(query: query, windows: windows) }
        }
    }
}
private extension URLSession {
    static func mock() -> URLSession {
        let testConfiguration = URLSessionConfiguration.default
        testConfiguration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: testConfiguration)
    }
}
private extension Suggestion {

    func expectedSuggestion(query: String, windows: [SuggestionContainerTests.Window]) -> SuggestionContainerTests.TestExpectations.ExpectedSuggestion? {
        let viewModel = SuggestionViewModel(isHomePage: false, suggestion: self, userStringValue: query)
        switch self {
        case .phrase(phrase: let phrase):
            return .init(type: .phrase, title: phrase, subtitle: viewModel.suffix ?? "", uri: nil, tabId: nil, score: 0)

        case .website(url: let url):
            return .init(type: .website, title: url.absoluteString, subtitle: viewModel.suffix ?? "", uri: url.absoluteString, tabId: nil, score: 0)

        case .bookmark(title: let title, url: let url, isFavorite: let isFavorite, score: let score):
            return .init(type: isFavorite ? .favorite : .bookmark, title: title, subtitle: viewModel.suffix ?? "", uri: url.absoluteString, tabId: nil, score: score)

        case .historyEntry(title: let title, url: let url, score: let score):
            return .init(type: .historyEntry, title: title ?? "", subtitle: viewModel.suffix ?? "", uri: url.absoluteString, tabId: nil, score: score)

        case .openTab(title: let title, url: let url, score: let score):
            var tabId: UUID?
            for window in windows {
                if let tabs = window.tabs.firstIndex(where: { $0.url == url && $0.title == title }) {
                    tabId = window.tabs[tabs].tabId
                }
                for tab in window.tabs {
                    if tab.url == url {
                        tabId = tab.tabId
                        break
                    }
                }
            }
            return .init(type: .openTab, title: title, subtitle: viewModel.suffix ?? "", uri: url.absoluteString, tabId: tabId, score: score)
        case .internalPage(title: let title, url: let url, score: let score):
            return .init(type: .internalPage, title: title, subtitle: viewModel.suffix ?? "", uri: url.absoluteString, tabId: nil, score: score)
        case .unknown:
            return nil
        }
    }
}
