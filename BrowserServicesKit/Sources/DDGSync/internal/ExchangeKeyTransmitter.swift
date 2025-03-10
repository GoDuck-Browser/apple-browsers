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

    func send(_ code: SyncCode.ExchangeKey, deviceName: String) async throws {
        let exchangInfo = try crypter.prepareForExchange()
        let exchangeKey = try JSONEncoder.snakeCaseKeys.encode(
            SyncCode(exchangeMessage: .init(keyId: exchangInfo.keyId, publicKey: exchangInfo.publicKey, deviceName: deviceName))
        )
        
        let base64ExchangeKey = exchangeKey.base64EncodedData()
        
        let encryptedRecoveryKey = try crypter.seal(base64ExchangeKey, secretKey: code.publicKey)

        let body = try JSONEncoder.snakeCaseKeys.encode(
            ExchangeRequest(keyId: code.keyId, encryptedRecoveryKey: encryptedRecoveryKey)
        )
        
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
        let encryptedRecoveryKey: Data
    }

}
