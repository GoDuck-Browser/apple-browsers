//
//  NewTabPageVPNStatsModel.swift
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
import CombineExtensions
import Common
import Foundation
import os.log
import Persistence
import PrivacyStats

public protocol NewTabPageVPNControlling {

    //var status: NewTabPage.NewTabPageVPNStatus { get }
    var statusPublisher: CurrentValuePublisher<NewTabPage.NewTabPageVPNStatus, Never> { get }

    /// Starts the VPN connection used for Network Protection
    ///
    func connect() async

    /// Stops the VPN connection used for Network Protection
    ///
    func disconnect() async
}

public enum NewTabPageVPNStatus {
    case unsubscribed
    case subscribed(connectionStatus: NewTabPageVPNConnectionStatus)
}

public enum NewTabPageVPNConnectionStatus {
    case disconnected(data: NewTabPageDataModel.VPNDisconnectedData)
    case connecting(data: NewTabPageDataModel.VPNDisconnectedData)
    case connected(activeSessionInfo: NewTabPageDataModel.VPNConnectedData)
    case disconnecting(activeSessionInfo: NewTabPageDataModel.VPNConnectedData)
}

public enum NewTabPageVPNStatsEvent: Equatable {
    case connect
    case disconnect
    case tryForFree
}

public final class NewTabPageVPNStatsModel {

    let vpnController: NewTabPageVPNControlling
    let statsUpdatePublisher: AnyPublisher<Void, Never>

    private let eventMapping: EventMapping<NewTabPageVPNStatsEvent>?

    private let statsUpdateSubject = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    public init(
        vpnController: NewTabPageVPNControlling,
        eventMapping: EventMapping<NewTabPageVPNStatsEvent>?) {

            self.eventMapping = eventMapping
            self.vpnController = vpnController

            statsUpdatePublisher = vpnController.statusPublisher
                .map { _ in }
                .eraseToAnyPublisher()
    }

    func connect() async {
        await vpnController.connect()
        eventMapping?.fire(.connect)
    }

    func disconnect() async {
        await vpnController.disconnect()
        eventMapping?.fire(.disconnect)
    }

    func tryForFree() {
        eventMapping?.fire(.tryForFree)
    }

    func getData() -> NewTabPageDataModel.VPNStatsData {
        switch vpnController.statusPublisher.value {
        case .unsubscribed:
            return NewTabPageDataModel.VPNStatsData(pending: "none", state: "unsubscribed")
        case .subscribed(let connectionStatus):
            switch connectionStatus {
            case .disconnected(let data):
                return NewTabPageDataModel.VPNStatsData(pending: "none", state: "disconnected", value: data)
            case .connecting(let data):
                return NewTabPageDataModel.VPNStatsData(pending: "connecting", state: "disconnected", value: data)
            case .connected(let data):
                return NewTabPageDataModel.VPNStatsData(pending: "none", state: "connected", value: data)
            case .disconnecting(let data):
                return NewTabPageDataModel.VPNStatsData(pending: "disconnecting", state: "connected", value: data)
            }
        }
    }
}
