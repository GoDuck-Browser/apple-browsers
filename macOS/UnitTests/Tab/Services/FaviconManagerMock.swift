//
//  FaviconManagerMock.swift
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

import XCTest
import Combine
import BrowserServicesKit
import Common
import History
@testable import DuckDuckGo_Privacy_Browser

final class FaviconManagerMock: FaviconManagement {

    func loadFavicons() {}
    @Published var areFaviconsLoaded = true
    var faviconsLoadedPublisher: Published<Bool>.Publisher { $areFaviconsLoaded }

    func handleFaviconLinks(_ faviconLinks: [FaviconUserScript.FaviconLink], documentUrl: URL) async -> Favicon? {
        nil
    }

    func handleFaviconsByDocumentUrl(_ faviconsByDocumentUrl: [URL: [Favicon]]) async {
        // no-op
    }

    func getCachedFaviconURL(for documentUrl: URL, sizeCategory: Favicon.SizeCategory, fallBackToSmaller: Bool) -> URL? {
        return nil
    }

    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory, fallBackToSmaller: Bool) -> Favicon? {
        return nil
    }

    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory, fallBackToSmaller: Bool) -> Favicon? {
        return nil
    }

    func getCachedFavicon(forDomainOrAnySubdomain host: String, sizeCategory: Favicon.SizeCategory, fallBackToSmaller: Bool) -> Favicon? {
        return nil
    }

    func burn(except fireproofDomains: DuckDuckGo_Privacy_Browser.FireproofDomains, bookmarkManager: DuckDuckGo_Privacy_Browser.BookmarkManager, savedLogins: Set<String>) async {
    }

    func burnDomains(_ domains: Set<String>, exceptBookmarks bookmarkManager: any DuckDuckGo_Privacy_Browser.BookmarkManager, exceptSavedLogins: Set<String>, exceptExistingHistory history: History.BrowsingHistory, tld: Common.TLD) async {
    }
}
