//
//  DuckPlayerBottomSheetView.swift
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
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI

struct DuckPlayerBottomSheetView: View {
    @ObservedObject var viewModel: DuckPlayerBottomSheetViewModel
    
    private let content: AnyView = AnyView(
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image("dax-icon")
                    .resizable()
                    .frame(width: 24, height: 24)
                
                Text("Open in Duck Player")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    //viewModel.openInDuckPlayer()
                }) {
                    Text("Open")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    )
    
    var body: some View {
        BottomSheet.Container<AnyView>(
            viewModel: viewModel.bottomSheetViewModel,
            content: { content }
        )
    }
}