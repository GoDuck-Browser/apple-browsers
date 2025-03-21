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
    func controllerWillBeginTransmittingRecoveryKey() async
    func controllerDidFinishTransmittingRecoveryKey()
    
    func controllerDidReceiveRecoveryKey()

    func controllerDidRecognizeScannedCode() async
    
    func controllerDidCreateSyncAccount()
    func controllerDidCompleteAccountConnection(shouldShowSyncEnabled: Bool)
    
    func controllerDidCompleteLogin(registeredDevices: [RegisteredDevice])
    
    func controllerDidFindTwoAccountsDuringRecovery(_ recoveryKey: SyncCode.RecoveryKey) async
    
    func controllerDidError(_ error: SyncActivationError, underlyingError: Error?)
}

enum SyncActivationError: Error {
    case unableToScanQRCode
    
    //unableToSyncWithDevice
    case failedToFetchPublicKey
    case failedToTransmitExchangeRecoveryKey
    case failedToFetchConnectRecoveryKey
    case failedToLogIn
    
    case failedToTransmitExchangeKey
    case failedToFetchExchangeRecoveryKey
    
    case failedToCreateAccount
    case failedToTransmitConnectRecoveryKey
    
    case foundExistingAccount
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
    
    func startExchangeMode() throws -> String {
        let exchanger = try syncService.remoteExchange()
        self.exchanger = exchanger
        startExchangePolling()
        return exchanger.code
    }
    
    func stopExchangeMode() {
        exchanger?.stopPolling()
        exchanger = nil
    }
    
    func startConnectMode() throws -> String {
        let connector = try syncService.remoteConnect()
        self.connector = connector
        self.startConnectPolling()
        
        // Step A
        return connector.code
    }
    
    func stopConnectMode() {
        self.connector?.stopPolling()
        self.connector = nil
    }
    
    func syncCodeEntered(code: String) async -> Bool {
        // Step B
        let syncCode: SyncCode
        do {
            syncCode = try SyncCode.decodeBase64String(code)
        } catch {
            await delegate?.controllerDidError(.unableToRecogniseCode, underlyingError: error)
            return false
        }
        
        await delegate?.controllerDidRecognizeScannedCode()

        if let exchangeKey = syncCode.exchangeKey {
            return await handleExchangeKey(exchangeKey)
        } else if let recoveryKey = syncCode.recovery {
            return await handleRecoveryKey(recoveryKey)
        } else if let connectKey = syncCode.connect {
            return await handleConnectKey(connectKey)
        } else {
            await delegate?.controllerDidError(.unableToRecogniseCode, underlyingError: nil)
            return false
        }
    }
    
    func loginAndShowDeviceConnected(recoveryKey: SyncCode.RecoveryKey) async throws {
        let registeredDevices = try await syncService.login(recoveryKey, deviceName: deviceName, deviceType: deviceType)
        await delegate?.controllerDidCompleteLogin(registeredDevices: registeredDevices)
    }
    
    private func startExchangePolling() {
        Task { @MainActor in
            let exchangeMessage: ExchangeMessage
            do {
                // Step C
                guard let message = try await exchanger?.pollForPublicKey() else {
                    // Polling likely cancelled
                    return
                }
                exchangeMessage = message
            } catch {
                delegate?.controllerDidError(.failedToFetchPublicKey, underlyingError: error)
                return
            }
            
            await delegate?.controllerWillBeginTransmittingRecoveryKey()
            do {
                // Step D
                try await syncService.transmitExchangeRecoveryKey(for: exchangeMessage)
            } catch {
                delegate?.controllerDidError(.failedToTransmitExchangeRecoveryKey, underlyingError: error)
            }
            
            delegate?.controllerDidFinishTransmittingRecoveryKey()
            exchanger?.stopPolling()
        }
    }
    
    private func startConnectPolling() {
        Task { @MainActor in
            let recoveryKey: SyncCode.RecoveryKey
            do {
                guard let key = try await connector?.pollForRecoveryKey() else {
                    // Polling likely cancelled
                    return
                }
                recoveryKey = key
            } catch {
                delegate?.controllerDidError(.failedToFetchConnectRecoveryKey, underlyingError: error)
                return
            }
            
            delegate?.controllerDidReceiveRecoveryKey()
            
            do {
                try await loginAndShowDeviceConnected(recoveryKey: recoveryKey)
            } catch {
                delegate?.controllerDidError(.failedToLogIn, underlyingError: error)
            }
        }
    }
    
    private func handleExchangeKey(_ exchangeKey: SyncCode.ExchangeKey) async -> Bool {
        let exchangeInfo: ExchangeInfo
        do {
            exchangeInfo = try await self.syncService.transmitGeneratedExchangeInfo(exchangeKey, deviceName: deviceName)
        } catch {
            await delegate?.controllerDidError(.failedToTransmitExchangeKey, underlyingError: error)
            return false
        }
        
        do {
            guard let recoveryKey = try await self.syncService.remoteExchangeAgain(exchangeInfo: exchangeInfo).pollForRecoveryKey() else {
                // Polling likelly cancelled.
                return false
            }
            return await handleRecoveryKey(recoveryKey)
        } catch {
            await delegate?.controllerDidError(.failedToFetchExchangeRecoveryKey, underlyingError: error)
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
                    await delegate?.controllerDidError(.failedToCreateAccount, underlyingError: error)
                }
            }
        }
        do {
            try await syncService.transmitRecoveryKey(connectKey)
            await delegate?.controllerDidCompleteAccountConnection(shouldShowSyncEnabled: shouldShowSyncEnabled)
        } catch {
            await delegate?.controllerDidError(.failedToTransmitConnectRecoveryKey, underlyingError: error)
            return false
        }

        return true
    }

    private func handleRecoveryCodeLoginError(recoveryKey: SyncCode.RecoveryKey, error: Error) async {
        if syncService.account != nil && featureFlagger.isFeatureOn(.syncSeamlessAccountSwitching) {
            await delegate?.controllerDidFindTwoAccountsDuringRecovery(recoveryKey)
        } else if syncService.account != nil {
            await delegate?.controllerDidError(.foundExistingAccount, underlyingError: error)
        } else {
            await delegate?.controllerDidError(.failedToLogIn, underlyingError: error)
        }
    }
}
