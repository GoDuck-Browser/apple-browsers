//
//  VPNAppEventsHandler.swift
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

import Foundation
import Common
import NetworkProtection
import os.log
import VPNAppState

final class VPNAppEventsHandler {

    private let appState: VPNAppState
    private let tunnelController: NetworkProtectionTunnelController

    init(tunnelController: NetworkProtectionTunnelController,
         appState: VPNAppState) {

        self.appState = appState
        self.tunnelController = tunnelController

        if !appState.isAuthV2Enabled {
            appState.resetIsMigratedToAuthV2()
        }
    }

    func appDidFinishLaunching() {
        let currentVersion = AppVersion.shared.versionAndBuildNumber
        let versionStore = NetworkProtectionLastVersionRunStore(userDefaults: .netP)
        defer {
            versionStore.lastAgentVersionRun = currentVersion
        }

        let restartTunnel = { [appState, tunnelController] in
            self.tunnelController.ensureRiskyDomainsEnabledIfNeeded()
            Logger.networking.info("App updated from \(versionStore.lastAgentVersionRun ?? "null", privacy: .public) to \(currentVersion, privacy: .public): updating login items")

            if appState.isAuthV2Enabled && !appState.isMigratedToAuthV2 {
                Task {
                    guard await !tunnelController.isConnected else {
                        return
                    }

                    await tunnelController.stop()
                    await tunnelController.start()
                    appState.isMigratedToAuthV2 = true
                }
            } else {
                self.restartTunnel()
            }
        }

#if DEBUG || REVIEW // Since DEBUG and REVIEW builds may not change version No. we want them to always reset.
        restartTunnel()
#else
        if versionStore.lastAgentVersionRun != currentVersion {
            restartTunnel()
        }
#endif
    }

    // MARK: - Private code

    private func restartTunnel() {
        Task {
            // Restart NetP SysEx on app update
            if await tunnelController.isConnected {
                await tunnelController.restart()
            }
        }
    }
}
