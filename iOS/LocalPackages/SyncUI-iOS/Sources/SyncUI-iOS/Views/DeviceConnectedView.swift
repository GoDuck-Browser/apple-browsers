//
//  DeviceConnectedView.swift
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

public struct DeviceConnectedView: View {

    var model: SyncSettingsViewModel

    @Environment(\.presentationMode) var presentation

    public init(model: SyncSettingsViewModel) {
        self.model = model
    }

    @ViewBuilder
    func deviceSyncedView() -> some View {
        UnderflowContainer {
            VStack(spacing: 0) {
                Image("Sync-Start-128")
                    .padding(20)

                Text(UserText.deviceSyncedSheetTitle)
                    .daxTitle1()
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .foregroundStyle(Color(designSystemColor: .textPrimary))
        } foregroundContent: {
            VStack {
                Button {
                    presentation.wrappedValue.dismiss()
                } label: {
                    Text(UserText.doneButton)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    presentation.wrappedValue.dismiss()
                    model.showOtherPlatformsPressed()
                } label: {
                    VStack {
                        Text(UserText.deviceSyncedSheetGetOnOtherDevicesButton)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 30)
        }
        .padding(.bottom)
        .background(Color(designSystemColor: .background))
    }

    public var body: some View {
        deviceSyncedView()
            .transition(.move(edge: .leading))
    }
}
