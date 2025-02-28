//
//  Suggestion.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation

public enum Suggestion: Equatable {

    case phrase(phrase: String)
    case website(url: URL)
    case bookmark(title: String, url: URL, isFavorite: Bool, score: Int)
    case historyEntry(title: String?, url: URL, score: Int)
    case internalPage(title: String, url: URL, score: Int)
    case openTab(title: String, url: URL, score: Int)
    case unknown(value: String)

    public var url: URL? {
        switch self {
        case .website(url: let url),
             .historyEntry(title: _, url: let url, _),
             .bookmark(title: _, url: let url, isFavorite: _, _),
             .internalPage(title: _, url: let url, _),
             .openTab(title: _, url: let url, _):
            return url
        case .phrase, .unknown:
            return nil
        }
    }

    var title: String? {
        switch self {
        case .historyEntry(title: let title, url: _, _):
            return title
        case .bookmark(title: let title, url: _, isFavorite: _, _),
             .internalPage(title: let title, url: _, _),
             .openTab(title: let title, url: _, _):
            return title
        case .phrase, .website, .unknown:
            return nil
        }
    }

    public var isOpenTab: Bool {
        if case .openTab = self {
            return true
        }
        return false
    }

    public var isBookmark: Bool {
        if case .bookmark = self {
            return true
        }
        return false
    }

    public var isHistoryEntry: Bool {
        if case .historyEntry = self {
            return true
        }
        return false
    }
}

extension Suggestion {

    public init?(bookmark: Bookmark, score: Int) {
        guard let urlObject = URL(string: bookmark.url) else { return nil }
        self = .bookmark(title: bookmark.title, url: urlObject, isFavorite: bookmark.isFavorite, score: score)
    }

    public init(historyEntry: HistorySuggestion, score: Int) {
        self = .historyEntry(title: historyEntry.title, url: historyEntry.url, score: score)
    }

    public init(internalPage: InternalPage, score: Int) {
        self = .internalPage(title: internalPage.title, url: internalPage.url, score: score)
    }

    public init(tab: BrowserTab, score: Int) {
        self = .openTab(title: tab.title, url: tab.url, score: score)
    }

    public init(url: URL) {
        self = .website(url: url)
    }

    public init(phrase: String, isNav: Bool) {
        if isNav, let url = URL(string: "http://\(phrase)") {
            self = .website(url: url)
        } else {
            self = .phrase(phrase: phrase)
        }
    }

}
