//
//  NewTabPageVPNStatsClient.swift
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

import Combine
import Common
import os.log
import UserScriptActionsManager
import WebKit

public final class NewTabPageVPNStatsClient: NewTabPageUserScriptClient {

    private let model: NewTabPageVPNStatsModel
    private var cancellables: Set<AnyCancellable> = []

    enum MessageName: String, CaseIterable {
        case getConfig = "vpn_getConfig"
        case getData = "vpn_getData"
        case onConfigUpdate = "vpn_onConfigUpdate"
        case onDataUpdate = "vpn_onDataUpdate"
        case setConfig = "vpn_setConfig"
        case connect = "vpn_connect"
        case disconnect = "vpn_disconnect"
        case tryForFree = "vpn_try"
    }

    public init(model: NewTabPageVPNStatsModel) {
        self.model = model
        super.init()
/*
        model.$isViewExpanded.dropFirst()
            .sink { [weak self] isExpanded in
                Task { @MainActor in
                    self?.notifyConfigUpdated(isExpanded)
                }
            }
            .store(in: &cancellables)*/

        model.statsUpdatePublisher
            .sink { [weak self] connectionStatus in
                Task { @MainActor in
                    await self?.notifyDataUpdated()
                }
            }
            .store(in: &cancellables)
    }

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) },
            MessageName.connect.rawValue: { [weak self] in try await self?.connect(params: $0, original: $1) },
            MessageName.disconnect.rawValue: { [weak self] in try await self?.disconnect(params: $0, original: $1) }
        ])
    }

    private func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .expanded)
    }

    @MainActor
    private func notifyConfigUpdated(_ isViewExpanded: Bool) {
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .expanded)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }

    @MainActor
    private func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = CodableHelper.decode(from: params) else {
            return nil
        }
        return nil
    }

    @MainActor
    private func notifyDataUpdated() async {
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: model.getData())
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        model.getData()
    }

    @MainActor
    private func connect(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await model.connect()
        return nil
    }

    @MainActor
    private func disconnect(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await model.disconnect()
        return nil
    }

    @MainActor
    private func tryForFree(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        model.tryForFree()
        return nil
    }
}
