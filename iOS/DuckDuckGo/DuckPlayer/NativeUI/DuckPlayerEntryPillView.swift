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
import DesignResourcesKit

struct DuckPlayerEntryPillView: View {
    @ObservedObject var viewModel: DuckPlayerEntryPillViewModel
    
    struct Constants {
        static let daxLogo = "Home"
        static let playImage = "play.fill"
    }

    private var sheetContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(Constants.daxLogo)
                    .resizable()
                    .frame(width: 40, height: 40)
                
                Text(UserText.duckPlayerNativeWatchOnYouTube)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    viewModel.openInDuckPlayer()
                }) {
                    Image(systemName: Constants.playImage)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(designSystemColor: .surface))        
        .cornerRadius(12)        
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)        
        .padding(.horizontal, 16)
        .padding(.vertical, 12)   
        .padding(.bottom, 80)     
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                ZStack {
                    // Background panel that extends beyond the bottom
                    VStack(spacing: 0) {
                        TopRoundedRectangle(radius: 12)
                            .fill(Color(designSystemColor: .panel))
                            .shadow(color: Color.black.opacity(0.08), radius: 8, y: -2)
                        
                        // Extra panel extension for bounce
                        Rectangle()
                            .fill(Color(designSystemColor: .panel))
                            .frame(height: 60)
                    }
                    
                    // Content
                    VStack {
                        sheetContent
                        Spacer()
                            .frame(height: 0)
                    }
                }
            }
            .offset(y: viewModel.isVisible ? 16 : geometry.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.spring(duration: 0.4, bounce: 0.5, blendDuration: 1.0), value: viewModel.isVisible)
    }
}

private struct TopRoundedRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)
        
        path.move(to: CGPoint(x: tl.x, y: tl.y + radius))
        
        // Top left corner
        path.addQuadCurve(to: CGPoint(x: tl.x + radius, y: tl.y),
                         control: tl)
        
        // Top edge
        path.addLine(to: CGPoint(x: tr.x - radius, y: tr.y))
        
        // Top right corner
        path.addQuadCurve(to: CGPoint(x: tr.x, y: tr.y + radius),
                         control: tr)
        
        // Right edge
        path.addLine(to: br)
        
        // Bottom edge
        path.addLine(to: bl)
        
        // Left edge
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + radius))
        
        return path
    }
}
