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

@MainActor
final class DuckPlayerBottomSheetViewModel: ObservableObject {
    private let duckPlayer: DuckPlayerControlling
    private let videoID: String
    
    let bottomSheetViewModel: BottomSheet.ViewModel
    
    init(duckPlayer: DuckPlayerControlling, videoID: String) {
        self.duckPlayer = duckPlayer
        self.videoID = videoID
        self.bottomSheetViewModel = BottomSheet.ViewModel()
    }
    
    func openInDuckPlayer() {
        duckPlayer.loadNativeDuckPlayerVideo(videoID: videoID, source: .youtube)
    }
    
    func show() {
        bottomSheetViewModel.show(anchoredTo: nil)
    }
} 