//
//  ExchangeKeyTransmitter.swift
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

import Foundation

// TODO: Create similar class for exchange flow

struct ExchangeKeyTransmitter: ExchangeKeyTransmitting {

    let endpoints: Endpoints
    let api: RemoteAPIRequestCreating
    let storage: SecureStoring
    let crypter: CryptingInternal

    // Step B
    func send(_ code: SyncCode.ExchangeKey, deviceName: String) async throws -> ExchangeInfo {
        let exchangeInfo = try crypter.prepareForExchange()
        let exchangeKey = try JSONEncoder.snakeCaseKeys.encode(
            SyncCode(exchangeMessage: .init(keyId: exchangeInfo.keyId, publicKey: exchangeInfo.publicKey, deviceName: deviceName))
        )
                
        let encryptedRecoveryKey = try crypter.seal(exchangeKey, secretKey: code.publicKey)
        let encodedRecoveryKey = encryptedRecoveryKey.base64EncodedString()

        let body = try JSONEncoder.snakeCaseKeys.encode(
            ExchangeRequest(keyId: code.keyId, encryptedMessage: encodedRecoveryKey)
        )
        
        print("🦄 B: Send public key with keyID: \(code.keyId), publicKey: \(code.publicKey)")
        Swift.print("Exchange JSON request is: \(String(data: body, encoding: .utf8) ?? "nil")")

        let request = api.createRequest(url: endpoints.exchange,
                                        method: .post,
                                        headers: [:], // TODO: Will we authenticate in certain scenarios?
                                        parameters: [:],
                                        body: body,
                                        contentType: "application/json")
        _ = try await request.execute()
        return exchangeInfo
    }
    
    // Step D
    func sendRecovery(_ code: SyncCode.RecoveryKey, keyID: String, publicKey: Data) async throws {
        let recoveryJSON = try SyncCode(recovery: code).toJSON()
        
        let encryptedRecoveryKey = try crypter.seal(recoveryJSON, secretKey: publicKey)
        let encodedRecoveryKey = encryptedRecoveryKey.base64EncodedString()

        let body = try JSONEncoder.snakeCaseKeys.encode(
            ExchangeRequest(keyId: keyID, encryptedMessage: encodedRecoveryKey)
        )
        
        print("🦄 D: Send recovery key with keyID: \(keyID), recoveryKey: \(recoveryJSON)")
        print("Exchange JSON request is: \(String(data: body, encoding: .utf8) ?? "nil")")

        let request = api.createRequest(url: endpoints.exchange,
                                        method: .post,
                                        headers: [:], // TODO: Will we authenticate in certain scenarios?
                                        parameters: [:],
                                        body: body,
                                        contentType: "application/json")
        _ = try await request.execute()
    }

    struct ExchangeRequest: Encodable {
        let keyId: String
        let encryptedMessage: String
    }

}
