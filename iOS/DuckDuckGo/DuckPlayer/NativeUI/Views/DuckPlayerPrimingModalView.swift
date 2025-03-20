//
//  DuckPlayerPrimingModalView.swift
//  DuckDuckGo
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

import DuckUI
import SwiftUI

struct DuckPlayerPrimingModalView: View {
    @ObservedObject var viewModel: DuckPlayerPrimingModalViewModel
    @Environment(\.colorScheme) var colorScheme
    
    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let spacing: CGFloat = 16
        static let buttonHeight: CGFloat = 44
        static let iconSize: CGFloat = 24
        static let maxWidth: CGFloat = 500
        static let imageHeight: CGFloat = 180
    }
    
    var body: some View {
        VStack(spacing: Constants.spacing) {
            headerView
            
            VStack(spacing: Constants.spacing) {
                Image("DuckPlayerPrimingImage")  // You'll need to add this asset
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: Constants.imageHeight)
                    .cornerRadius(Constants.cornerRadius)
                
                Text("DuckDuckGo comes free with Duck Player!")
                    .daxTitle2()
                    .foregroundColor(Color(designSystemColor: .textPrimary))
                    .multilineTextAlignment(.center)
                
                Text("Watch videos without targeted ads and what you watch won't influence recommendations.")
                    .daxBodyRegular()
                    .foregroundColor(Color(designSystemColor: .textSecondary))
                    .multilineTextAlignment(.center)
                
                Button(action: { viewModel.tryDuckPlayer() }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                        Text("Try Duck Player")
                            .daxBodyBold()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.buttonHeight)
                    .background(Color(designSystemColor: .background))
                    .cornerRadius(Constants.cornerRadius)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(designSystemColor: .backdrop))
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            
            Button(action: { viewModel.dismiss() }) {
                Image(systemName: "xmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .foregroundColor(Color(designSystemColor: .textPrimary))
            }
            .padding()
        }
    }
}

#Preview {
    DuckPlayerPrimingModalView(viewModel: DuckPlayerPrimingModalViewModel())
}
