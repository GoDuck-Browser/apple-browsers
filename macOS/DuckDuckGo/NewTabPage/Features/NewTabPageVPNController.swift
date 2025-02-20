//
//  NewTabPageVPNController.swift
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
import NetworkProtection
import NetworkProtectionIPC
import NewTabPage
import NetworkProtectionUI

class NewTabPageVPNController {

    private let tunnelController: NetworkProtectionIPCTunnelController
    private let vpnControllerXPCClient: VPNControllerXPCClient
    private var cancellables = Set<AnyCancellable>()
    private var lastConnectedDate = Date()

    var statusPublisher: CombineExtensions.CurrentValuePublisher<NewTabPage.NewTabPageVPNStatus, Never>

    init(tunnelController: NetworkProtectionIPCTunnelController = TunnelControllerProvider.shared.tunnelController,
         vpnControllerXPCClient: VPNControllerXPCClient = .shared) {

        self.tunnelController = tunnelController
        self.vpnControllerXPCClient = vpnControllerXPCClient

        let initialValue: NewTabPage.NewTabPageVPNStatus = .subscribed(connectionStatus: Self.map(vpnControllerXPCClient.connectionStatusObserver.recentValue))

        let publisher = vpnControllerXPCClient.connectionStatusObserver.publisher.map { connectionStatus in

            NewTabPage.NewTabPageVPNStatus.subscribed(connectionStatus: Self.map(connectionStatus))
        }

        statusPublisher = CombineExtensions.CurrentValuePublisher<NewTabPage.NewTabPageVPNStatus, Never>(initialValue: initialValue, publisher: publisher.eraseToAnyPublisher())
    }

    private static func map(_ connectionStatus: ConnectionStatus) -> NewTabPage.NewTabPageVPNConnectionStatus {
        switch connectionStatus {
        case .connected(let connectedDate):
            let dataVolume = NewTabPageDataModel.VPNActiveSessionInfo.DataVolume(upload: 0, download: 0, unit: "mb/s")

            let activeSessionInfo = NewTabPageDataModel.VPNActiveSessionInfo(currentIp: "1.1.1.1", connectedSince: connectedDate, dataVolume: dataVolume)

            let history = makeFakeVPNUsageHistory()

            let connectedData = NewTabPageDataModel.VPNConnectedData(session: activeSessionInfo, history: history)

            return .connected(activeSessionInfo: connectedData)
        case .disconnected, .notConfigured:
            let data = NewTabPageDataModel.VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .disconnected(data: data)
        case .connecting, .reasserting:
            let data = NewTabPageDataModel.VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .connecting(data: data)
        case .disconnecting, .snoozing:
            let data = NewTabPageDataModel.VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .disconnected(data: data)
        }
    }

    private static func makeFakeVPNUsageHistory() -> NewTabPageDataModel.VPNUsageHistory {
        let days = [
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .sunday, value: 3.4),
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .monday, value: 5.6),
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .tuesday, value: 2.1),
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .wednesday, value: 0.0),
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .thursday, value: 8.0),
            NewTabPageDataModel.VPNDailyUsage(active: true, day: .friday, value: 16.0),
            NewTabPageDataModel.VPNDailyUsage(active: false, day: .saturday, value: 0),
        ]
        let weeklyUsage = NewTabPageDataModel.VPNWeeklyUsage(days: days, maxValue: 24)
        return NewTabPageDataModel.VPNUsageHistory(longestConnection: 8, weeklyUsage: weeklyUsage)
    }
}

extension NewTabPageVPNController: NewTabPageVPNControlling {

    func connect() async {
        await TunnelControllerProvider.shared.tunnelController.start()
    }
    
    func disconnect() async {
        await TunnelControllerProvider.shared.tunnelController.stop()
    }
}
