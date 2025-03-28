//
//  ExpandableButtonView.swift
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

import SwiftUI

struct ExpandableButtonView: View {
    @StateObject var viewModel: ExpandableButtonViewModel
    @State private var isHovered = false
    private let iconSize: CGFloat = 14
    @State private var isExpanded = false

    var body: some View {
        Button(action: {
            viewModel.buttonPressed()
        }) {
            ZStack(alignment: .trailing) {
                HStack {
                    Spacer()
                    HStack {
                        Image(viewModel.icon)
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                            .scaleEffect(isHovered ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isHovered)
                            .onHover { hovering in
                                isHovered = hovering
                            }
                        if isExpanded {
                            Text(viewModel.text)
                                .foregroundColor(.primary)
                                .transition(.opacity)

                            if let symbols = viewModel.shortcutSymbols {
                                HStack(spacing: 4) {
                                    ForEach(symbols, id: \.self) { symbol in
                                        Image(systemName: symbol)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.primary)
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal, isExpanded ? 12 : 4)
                    .padding(.vertical, 4)
                    .frame(minHeight: 26)
                    .background(
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 5)
                                .foregroundColor(Color(.buttonMouseOver))
                                .frame(width: isExpanded ? geo.size.width : 0, height: geo.size.height)
                                .opacity(isExpanded ? 1 : 0)
                                .animation(.easeInOut(duration: viewModel.animationDuration), value: isExpanded)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                        }
                    )
                }
            }
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())

        .onChange(of: viewModel.isExpanded) { value in
            withAnimation(.easeInOut(duration: viewModel.animationDuration)) {
                isExpanded.toggle()
            }
        }
    }
}
