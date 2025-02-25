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
    var onOpen: () -> Void
    
    @Published var isVisible: Bool = false
    private(set) var shouldAnimate: Bool = true
    
    init(onOpen: @escaping () -> Void) {        
        self.onOpen = onOpen
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
} 
