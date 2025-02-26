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
            .padding(.bottom, 25) // Add padding to cover boder during animation                      
        }
    }
    
    var body: some View {        
        ZStack(alignment: .bottom) {
            Color(designSystemColor: .panel)                
            sheetContent
        }
        .clipShape(CustomRoundedCorners(radius: 12, corners: [.topLeft, .topRight]))          
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .offset(y: 20)
    }
}


struct CustomRoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}