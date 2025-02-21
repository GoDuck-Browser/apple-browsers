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

    typealias VPNActiveSessionInfo = NewTabPageDataModel.VPNActiveSessionInfo
    typealias VPNConnectedData = NewTabPageDataModel.VPNConnectedData
    typealias VPNConnectionStatus = NewTabPage.NewTabPageVPNConnectionStatus
    typealias VPNDailyUsage = NewTabPageDataModel.VPNDailyUsage
    typealias VPNDataVolume = VPNActiveSessionInfo.DataVolume
    typealias VPNDisconnectedData = NewTabPageDataModel.VPNDisconnectedData
    typealias VPNStatus = NewTabPage.NewTabPageVPNStatus
    typealias VPNStatusPublisher = CombineExtensions.CurrentValuePublisher<VPNStatus, Never>
    typealias VPNUsageHistory = NewTabPageDataModel.VPNUsageHistory
    typealias VPNUsageTimespan = NewTabPageDataModel.VPNUsageTimespan
    typealias VPNWeeklyUsage = NewTabPageDataModel.VPNWeeklyUsage

    private let tunnelController: NetworkProtectionIPCTunnelController
    private let vpnControllerXPCClient: VPNControllerXPCClient
    private var cancellables = Set<AnyCancellable>()
    private var lastConnectedDate = Date()

    var statusPublisher: VPNStatusPublisher

    init(tunnelController: NetworkProtectionIPCTunnelController = TunnelControllerProvider.shared.tunnelController,
         vpnControllerXPCClient: VPNControllerXPCClient = .shared) {

        self.tunnelController = tunnelController
        self.vpnControllerXPCClient = vpnControllerXPCClient

        let initialConnectionStatus = Self.map(
            connectionStatus: vpnControllerXPCClient.connectionStatusObserver.recentValue,
            serverInfo: vpnControllerXPCClient.serverInfoObserver.recentValue,
            dataVolume: vpnControllerXPCClient.ipcDataVolumeObserver.recentValue)

        let initialSubscriptionStatus = VPNStatus.subscribed(connectionStatus: initialConnectionStatus)

        let publisher = vpnControllerXPCClient.connectionStatusObserver.publisher
            .combineLatest(vpnControllerXPCClient.serverInfoObserver.publisher)
            .combineLatest(vpnControllerXPCClient.ipcDataVolumeObserver.publisher)
            .map { values in

                VPNStatus.subscribed(
                    connectionStatus: Self.map(connectionStatus: values.0.0,
                                               serverInfo: values.0.1,
                                               dataVolume: values.1))
            }

        statusPublisher = VPNStatusPublisher(
            initialValue: initialSubscriptionStatus,
            publisher: publisher.eraseToAnyPublisher())
    }

    private static func map(connectionStatus: ConnectionStatus, serverInfo: NetworkProtectionStatusServerInfo, dataVolume: DataVolume) -> VPNConnectionStatus {

        switch connectionStatus {
        case .connected(let connectedDate):
            let dataVolume = VPNDataVolume(
                upload: dataVolume.bytesSent / 1024,
                download: dataVolume.bytesReceived / 1024,
                unit: "KB")

            let activeSessionInfo = VPNActiveSessionInfo(currentIp: serverInfo.serverAddress ?? "unknown", connectedSince: connectedDate, dataVolume: dataVolume)

            let history = makeFakeVPNUsageHistory()

            let connectedData = VPNConnectedData(session: activeSessionInfo, history: history)

            return .connected(activeSessionInfo: connectedData)
        case .disconnected, .notConfigured:
            let data = VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .disconnected(data: data)
        case .connecting, .reasserting:
            let data = VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .connecting(data: data)
        case .disconnecting, .snoozing:
            let data = VPNDisconnectedData(history: makeFakeVPNUsageHistory())
            return .disconnected(data: data)
        }
    }

    private static func makeFakeVPNUsageHistory() -> VPNUsageHistory {
        let days = [
            VPNDailyUsage(active: false, day: .sunday, value: 3.4),
            VPNDailyUsage(active: false, day: .monday, value: 5.6),
            VPNDailyUsage(active: false, day: .tuesday, value: 2.1),
            VPNDailyUsage(active: false, day: .wednesday, value: 15.0),
            VPNDailyUsage(active: false, day: .thursday, value: 8.0),
            VPNDailyUsage(active: true, day: .friday, value: 16.0),
            VPNDailyUsage(active: false, day: .saturday, value: 0),
        ]
        let weeklyUsage = VPNWeeklyUsage(days: days, maxValue: 24)
        return VPNUsageHistory(
            longestConnection: VPNUsageTimespan(duration: 45007),
            weeklyUsage: weeklyUsage)
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
