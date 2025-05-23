//
//  SyncWithServerView.swift
//  DuckDuckGo
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import DuckUI
import DesignResourcesKit

public struct SyncWithServerView: View {

    @ObservedObject public var model: SyncSettingsViewModel
    var onCancel: () -> Void

    public init(model: SyncSettingsViewModel, onCancel: @escaping () -> Void) {
        self.model = model
        self.onCancel = onCancel
    }

    public var body: some View {
        UnderflowContainer {
            VStack(spacing: 0) {
                HStack {
                    Button(action: onCancel, label: {
                        Text(UserText.cancelButton)
                    })
                    Spacer()
                }
                .frame(height: 56)
                .padding(.bottom, 20)
                Image("Sync-Server-128")
                    .padding(.bottom, 20)

                Text(UserText.connectWithServerSheetTitle)
                    .daxTitle1()
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                VStack(spacing: 16) {
                    Text(UserText.connectWithServerSheetDescriptionPart1)
                        .multilineTextAlignment(.center)

                    Text(UserText.connectWithServerSheetDescriptionPart2)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(Color(designSystemColor: .textPrimary))
            .padding(.horizontal, 20)
        } foregroundContent: {
            VStack(spacing: 8) {
                Button {
                    model.startSyncPressed()
                } label: {
                    Text(UserText.connectWithServerSheetButton)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 360)
                .padding(.horizontal, 30)
                .padding(.bottom, 8)
                Text(UserText.connectWithServerSheetFooter)
                    .daxFootnoteRegular()
                    .foregroundColor(Color(designSystemColor: .textSecondary))
            }
        }
        .background(Color(designSystemColor: .background))
    }
}
