//
//  DuckPlayerURLExtensionTests.swift
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
import os.log
import DuckPlayer

final class DuckPlayerURLExtensionTests: XCTestCase {

        #if os(iOS)
        let baseUrl = "https://m.youtube.com"
        #else
        let baseUrl = "https://www.youtube.com"
        #endif

    func testIsDuckPlayerScheme() {
        XCTAssertTrue("duck:player/abcdef12345".url!.isDuckURLScheme)
        XCTAssertTrue("duck://player/abcdef12345".url!.isDuckURLScheme)
        XCTAssertTrue("duck://player/abcdef".url!.isDuckURLScheme)
        XCTAssertTrue("duck://player/12345".url!.isDuckURLScheme)
        XCTAssertFalse("http://duckplayer/abcdef12345".url!.isDuckURLScheme)
        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345".url!.isDuckURLScheme)
        XCTAssertFalse("https://www.youtube-nocookie.com/embed/abcdef12345".url!.isDuckURLScheme)
    }

    func testIsDuckPlayer() {
        XCTAssertTrue("https://www.youtube-nocookie.com/embed/abcdef12345".url!.isDuckPlayer)
        XCTAssertTrue("https://www.youtube-nocookie.com/embed/abcdef12345?t=23s".url!.isDuckPlayer)

        XCTAssertFalse("https://www.youtube-nocookie.com/embed".url!.isDuckPlayer)
        XCTAssertFalse("https://www.youtube-nocookie.com/embed?t=23s".url!.isDuckPlayer)

        XCTAssertTrue("duck://player/abcdef12345".url!.isDuckPlayer)
        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345".url!.isDuckPlayer)
        XCTAssertFalse("https://duckduckgo.com".url!.isDuckPlayer)
    }

    func testIsYoutubePlaylist() {
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertTrue("\(baseUrl)/watch?list=abcdefgh12345678&v=abcdef12345".url!.isYoutubePlaylist)

        XCTAssertFalse("https://duckduckgo.com/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertFalse("\(baseUrl)/watch?list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345&list=abcdefgh12345678&index=1".url!.isYoutubePlaylist)
    }

    func testIsYoutubeVideo() {
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345".url!.isYoutubeVideo)
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345&list=abcdefgh12345678&index=1".url!.isYoutubeVideo)
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345&t=5m".url!.isYoutubeVideo)

        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubeVideo)
        XCTAssertFalse("https://duckduckgo.com/watch?v=abcdef12345".url!.isYoutubeVideo)
    }

    func testYoutubeVideoParamsFromDuckPlayerURL() {
        let params = "duck://player/abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "duck://player/abcdef12345?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")
    }

    func testYoutubeVideoParamsFromYoutubeURL() {
        let params = "\(baseUrl)/watch?v=abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "\(baseUrl)/watch?v=abcdef12345&t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")

        let paramsWithTimestampWithoutUnits = "\(baseUrl)/watch?t=102&v=abcdef12345&feature=youtu.be".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestampWithoutUnits?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestampWithoutUnits?.timestamp, "102")
    }

    func testYoutubeVideoParamsFromYoutubeNocookieURL() {
        let params = "https://www.youtube-nocookie.com/embed/abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "https://www.youtube-nocookie.com/embed/abcdef12345?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")
    }

    func testDuckPlayerURLTimestampValidation() {
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: nil).absoluteString, "duck://player/abcdef12345")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "23s").absoluteString, "duck://player/abcdef12345?t=23s")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "5m5s").absoluteString, "duck://player/abcdef12345?t=5m5s")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "12h400m100s").absoluteString, "duck://player/abcdef12345?t=12h400m100s")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "12h2s2h").absoluteString, "duck://player/abcdef12345?t=12h2s2h")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "5m5m5m").absoluteString, "duck://player/abcdef12345?t=5m5m5m")

        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "5").absoluteString, "duck://player/abcdef12345?t=5")
        XCTAssertEqual(URL.duckPlayer("abcdef12345", timestamp: "10d").absoluteString, "duck://player/abcdef12345")
    }

    func testYoutubeURLTimestampValidation() {
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: nil).absoluteString, "\(baseUrl)/watch?v=abcdef12345")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "23s").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=23s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5m5s").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=5m5s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "12h400m100s").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=12h400m100s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "12h2s2h").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=12h2s2h")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5m5m5m").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=5m5m5m")

        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5").absoluteString, "\(baseUrl)/watch?v=abcdef12345&t=5")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "10d").absoluteString, "\(baseUrl)/watch?v=abcdef12345")
    }

    func testYoutubeNoCookieURLTimestampValidation() {
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: nil).absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "23s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=23s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5m5s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5m5s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "12h400m100s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=12h400m100s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "12h2s2h").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=12h2s2h")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5m5m5m").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5m5m5m")

        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "10d").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345")
    }

    func testIsYoutubeWatchWithHashtag() {
        // Valid YouTube watch URL with a video ID and a hashtag
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345#t=2m30s".url!.isYoutubeWatchWithHashtag)
        XCTAssertTrue("\(baseUrl)/watch?v=abcdef12345&list=123456#player".url!.isYoutubeWatchWithHashtag)

        // YouTube watch URL with a video ID but no fragment
        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345".url!.isYoutubeWatchWithHashtag)

        // YouTube watch URL with an empty fragment
        XCTAssertFalse("\(baseUrl)/watch?v=abcdef12345#".url!.isYoutubeWatchWithHashtag)

        // URL that is not a YouTube watch page
        XCTAssertFalse("\(baseUrl)/playlist?list=12345#player".url!.isYoutubeWatchWithHashtag)

        // Non-YouTube URL with a fragment
        XCTAssertFalse("https://duckduckgo.com/search?q=test#results".url!.isYoutubeWatchWithHashtag)

        // YouTube watch URL missing video ID parameter
        XCTAssertFalse("\(baseUrl)/watch?list=12345#player".url!.isYoutubeWatchWithHashtag)
    }

}
