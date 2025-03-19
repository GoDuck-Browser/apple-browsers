//
//  SyncActivationController.swift
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

import Foundation
import DDGSync
import BrowserServicesKit
import Core

@MainActor
protocol SyncActivationControllerDelegate: AnyObject {
    func controllerDidReceiveError(_ type: SyncErrorMessage, underlyingError: Error?, relatedPixelEvent: Pixel.Event)
    func controllerWillBeginTransmittingRecoveryKey() async
    func controllerDidFinishTransmittingRecoveryKey()
    
    func controllerDidReceiveRecoveryKey()

    func controllerDidRecognizeScannedCode() async
    func controllerDidNOTRecognizeScannedCode()
    
    func controllerDidCreateSyncAccount()
    func controllerDidCompleteAccountConnection(shouldShowSyncEnabled: Bool)
    
    func controllerDidCompleteLogin(registeredDevices: [RegisteredDevice])
    
    func controllerDidFindTwoAccountsDuringRecovery(_ recoveryKey: SyncCode.RecoveryKey) async
}

final class SyncActivationController {
    private let deviceName: String
    private let deviceType: String
    private let source: String?
    private let syncService: DDGSyncing
    private let featureFlagger: FeatureFlagger
    
    weak var delegate: SyncActivationControllerDelegate?
    
    private var exchanger: RemoteKeyExchanging?
    private var connector: RemoteConnecting?
    
    var recoveryCode: String {
        guard let code = syncService.account?.recoveryCode else {
            return ""
        }

        return code
    }
    
    init(deviceName: String, deviceType: String, source: String?, syncService: DDGSyncing, featureFlagger: FeatureFlagger, delegate: SyncActivationControllerDelegate? = nil) {
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.source = source
        self.syncService = syncService
        self.featureFlagger = featureFlagger
        self.delegate = delegate
    }
    
    func startExchangeMode() -> String? {
        do {
            return try startExchangePolling()
        } catch {
            Task {
                await delegate?.controllerDidReceiveError(SyncErrorMessage.unableToSyncToServer, underlyingError: error, relatedPixelEvent: .syncLoginError)
            }
            return nil
        }
    }
    
    func stopExchangeMode() {
        exchanger?.stopPolling()
        exchanger = nil
    }
    
    func startConnectMode() -> String? {
        do {
            let connector = try syncService.remoteConnect()
            self.connector = connector
            self.startConnectPolling()
            return connector.code
        } catch {
            Task {
                await delegate?.controllerDidReceiveError(SyncErrorMessage.unableToSyncToServer, underlyingError: error, relatedPixelEvent: .syncLoginError)
            }
            return nil
        }
    }
    
    func stopConnectMode() {
        self.connector?.stopPolling()
        self.connector = nil
    }
    
    func syncCodeEntered(code: String) async -> Bool {
        guard let syncCode = try? SyncCode.decodeBase64String(code) else {
            await delegate?.controllerDidNOTRecognizeScannedCode()
            return false
        }
        await delegate?.controllerDidRecognizeScannedCode()

        if let exchangeKey = syncCode.exchangeKey {
            return await handleExchangeKey(exchangeKey)
        } else if let recoveryKey = syncCode.recovery {
            return await handleRecoveryKey(recoveryKey)
        } else if let connectKey = syncCode.connect {
            return await handleConnectKey(connectKey)
        }
        return false
    }
    
    func loginAndShowDeviceConnected(recoveryKey: SyncCode.RecoveryKey) async throws {
        let registeredDevices = try await syncService.login(recoveryKey, deviceName: deviceName, deviceType: deviceType)
        await delegate?.controllerDidCompleteLogin(registeredDevices: registeredDevices)
    }
    
    private func startExchangePolling() throws -> String {
        let exchanger = try syncService.remoteExchange()
        self.exchanger = exchanger
        Task { @MainActor in
            do {
                // Step C
                if let exchangeMessage = try await exchanger.pollForPublicKey() {
                    await delegate?.controllerWillBeginTransmittingRecoveryKey()
                    try await syncService.transmitExchangeRecoveryKey(for: exchangeMessage)
                    // TODO: Still has the preparingSync view showing
                    delegate?.controllerDidFinishTransmittingRecoveryKey()
                } else {
                    // Polling likelly cancelled
                    return
                }
            } catch {
                // TODO: Handle this properly
                delegate?.controllerDidReceiveError(SyncErrorMessage.unhandledError, underlyingError: error, relatedPixelEvent: .syncLoginError)
            }
            exchanger.stopPolling()
        }
        return exchanger.code
    }
    
    private func startConnectPolling() {
        Task { @MainActor in
            do {
                if let recoveryKey = try await connector?.pollForRecoveryKey() {
                    delegate?.controllerDidReceiveRecoveryKey()
                    try await loginAndShowDeviceConnected(recoveryKey: recoveryKey)
                } else {
                    return
                }
            } catch {
                delegate?.controllerDidReceiveError(SyncErrorMessage.unableToSyncWithDevice, underlyingError: error, relatedPixelEvent: .syncLoginError)
            }
        }
    }
    
    private func handleExchangeKey(_ exchangeKey: SyncCode.ExchangeKey) async -> Bool {
        do {
            // Step B
            let exchangeInfo = try await self.syncService.transmitGeneratedExchangeInfo(exchangeKey, deviceName: deviceName)
            // Step E
            guard let recoveryKey = try await self.syncService.remoteExchangeAgain(exchangeInfo: exchangeInfo).pollForRecoveryKey() else {
                // Polling likelly cancelled. Would love to handle this in a more elegant way.
                return false
            }
            return await handleRecoveryKey(recoveryKey)
        } catch {
            // TODO: Handle this properly
            await delegate?.controllerDidReceiveError(SyncErrorMessage.unhandledError, underlyingError: error, relatedPixelEvent: .syncLoginError)
            return false
        }
    }
    
    private func handleRecoveryKey(_ recoveryKey: SyncCode.RecoveryKey) async -> Bool {
        do {
            try await loginAndShowDeviceConnected(recoveryKey: recoveryKey)
            return true
        } catch {
            await handleRecoveryCodeLoginError(recoveryKey: recoveryKey, error: error)
            return false
        }
    }
    
    private func handleConnectKey(_ connectKey: SyncCode.ConnectCode) async -> Bool {
        var shouldShowSyncEnabled = true
        
        if syncService.account == nil {
            do {
                try await syncService.createAccount(deviceName: deviceName, deviceType: deviceType)
                let additionalParameters = source.map { ["source": $0] } ?? [:]
                try await Pixel.fire(pixel: .syncSignupConnect, withAdditionalParameters: additionalParameters, includedParameters: [.appVersion])
                await delegate?.controllerDidCreateSyncAccount()
                shouldShowSyncEnabled = false
            } catch {
                Task {
                    await delegate?.controllerDidReceiveError(.unableToSyncToServer, underlyingError: error, relatedPixelEvent: .syncSignupError)
                }
            }
        }
        do {
            try await syncService.transmitRecoveryKey(connectKey)
            await delegate?.controllerDidCompleteAccountConnection(shouldShowSyncEnabled: shouldShowSyncEnabled)
        } catch {
            await delegate?.controllerDidReceiveError(.unableToSyncWithDevice, underlyingError: error, relatedPixelEvent: .syncLoginError)
            return false
        }

        return true
    }

    private func handleRecoveryCodeLoginError(recoveryKey: SyncCode.RecoveryKey, error: Error) async {
        if syncService.account != nil && featureFlagger.isFeatureOn(.syncSeamlessAccountSwitching) {
            await delegate?.controllerDidFindTwoAccountsDuringRecovery(recoveryKey)
        } else if syncService.account != nil {
            await delegate?.controllerDidReceiveError(.unableToMergeTwoAccounts, underlyingError: error, relatedPixelEvent: .syncLoginExistingAccountError)
        } else {
            await delegate?.controllerDidReceiveError(.unableToSyncToServer, underlyingError: error, relatedPixelEvent: .syncLoginError)
        }
    }
}
