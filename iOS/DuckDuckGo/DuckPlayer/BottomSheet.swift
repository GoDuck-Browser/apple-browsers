// 
// BottomSheet.swift
// DuckDuckGo
// 
// Copyright © 2024 DuckDuckGo. All rights reserved.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 

import SwiftUI
import Combine

public enum BottomSheet {
    
    @MainActor
    public final class ViewModel: ObservableObject {
        @Published public private(set) var sheetVisible = false
        
        public func show(anchoredTo rect: CGRect?) {
            sheetVisible = true
        }
    }
    
    public struct Container<Content: View>: View {
        @ObservedObject var viewModel: ViewModel
        let content: () -> Content
        
        public init(
            viewModel: ViewModel,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.viewModel = viewModel
            self.content = content
        }
        
        public var body: some View {
            ZStack {
                // Make background clear and non-interactive
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
                
                VStack {
                    Spacer()
                    if viewModel.sheetVisible {
                        content()
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

}
