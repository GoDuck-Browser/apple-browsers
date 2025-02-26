//
//  DuckPlayerBottomSheetView.swift
//  DuckDuckGo
//
//  Copyright 2024 DuckDuckGo. All rights reserved.
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
    
    // Add state to track the height
    @State private var viewHeight: CGFloat = 100
    @State private var iconSize: CGFloat = 40

    struct Constants {
        static let daxLogo = "Home"
        static let playImage = "play.fill"
    }

    private var sheetContent: some View {
        Button(action: { viewModel.openInDuckPlayer()}) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(Constants.daxLogo)
                        .resizable()
                        .frame(width: 40, height: 40)
                    
                    Text(UserText.duckPlayerNativeOpenInDuckPlayer)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(designSystemColor: .textPrimary))
                    
                    Spacer()
                    
                    Image(systemName: Constants.playImage)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.blue)
                        .clipShape(Circle())
            
                }
                .padding(16)                
            }
            .background(Color(designSystemColor: .surface))        
            .cornerRadius(12)        
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)   
            .padding(16)                 
        }
    }
    
    var body: some View {        
        ZStack(alignment: .bottom) {
            sheetContent
        }           
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
