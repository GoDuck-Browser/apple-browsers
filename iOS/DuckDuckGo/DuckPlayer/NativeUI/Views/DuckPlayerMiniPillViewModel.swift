//
//  DuckPlayerBottomSheetViewModel.swift
//  DuckDuckGo
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import Combine
import SwiftUI
import WebKit

final class DuckPlayerMiniPillViewModel: ObservableObject {
    var onOpen: () -> Void
    var videoID: String = ""

    @Published var isVisible: Bool = false
    @Published var title: String = ""
    @Published var thumbnailURL: URL?
    @Published var authorName: String?

    private(set) var shouldAnimate: Bool = true
    private var titleUpdateTask: Task<Void, Error>?
    private var oEmbedService: YoutubeOembedService

   init(onOpen: @escaping () -> Void, videoID: String, oEmbedService: YoutubeOembedService = DefaultYoutubeOembedService()) {
    self.onOpen = onOpen
    self.videoID = videoID
    self.oEmbedService = oEmbedService
    Task { try await updateMetadata() }

}

    func updateOnOpen(_ onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        shouldAnimate = false
    }

    func openInDuckPlayer() {
        onOpen()
    }

    func show() {
        self.isVisible = true
    }

    func hide() {
        isVisible = false
    }

    // Gets the video title from the Youtube API oembed endpoint
    private func updateMetadata() async throws {
        if let response = await oEmbedService.fetchMetadata(for: videoID) {
            self.title = response.title
            self.authorName = response.author_name
            self.thumbnailURL = URL(string: response.thumbnail_url)
        }

    }

}
