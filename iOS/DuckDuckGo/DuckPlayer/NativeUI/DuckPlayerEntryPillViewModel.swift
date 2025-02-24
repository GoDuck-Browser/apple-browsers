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
final class DuckPlayerEntryPillViewModel: ObservableObject {
    private let videoID: String
    private let onOpen: () -> Void
    
    @Published var isVisible: Bool = false
    
    init(videoID: String, onOpen: @escaping () -> Void) {
        self.videoID = videoID
        self.onOpen = onOpen
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
} 
