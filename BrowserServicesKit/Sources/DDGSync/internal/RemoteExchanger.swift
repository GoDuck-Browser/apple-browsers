//
//  RemoteExchanger.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class RemoteExchanger: RemoteExchanging {

    let code: String
    let exchangeInfo: ExchangeInfo

    let crypter: CryptingInternal
    let api: RemoteAPIRequestCreating
    let endpoints: Endpoints

    var isPolling = false

    init(crypter: CryptingInternal,
         api: RemoteAPIRequestCreating,
         endpoints: Endpoints,
         exchangeInfo: ExchangeInfo) throws {
        self.crypter = crypter
        self.api = api
        self.endpoints = endpoints
        self.exchangeInfo = exchangeInfo
        self.code = try exchangeInfo.toCode()
    }

    func pollForExchangeKey() async throws -> SyncCode.ExchangeKey? {
        assert(!isPolling, "exchanger is already polling")

        isPolling = true
        while isPolling {
            if let key = try await fetchExchangeKey() {
                return key
            }

            if isPolling {
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            }
        }
        return nil
    }

    func stopPolling() {
        isPolling = false
    }

    private func fetchExchangeKey() async throws -> SyncCode.ExchangeKey? {
        if let encryptedExchangeKey = try await fetchEncryptedExchangeKey() {
            let exchangeKey = try decryptEncryptedExchangeKey(encryptedExchangeKey)
            return exchangeKey
        }
        return nil
    }

    private func decryptEncryptedExchangeKey(_ encryptedExchangeKey: Data) throws -> SyncCode.ExchangeKey {
        let data = try crypter.unseal(encryptedData: encryptedExchangeKey,
                                      publicKey: exchangeInfo.publicKey,
                                      secretKey: exchangeInfo.secretKey)

        guard let exchangeKey = try JSONDecoder.snakeCaseKeys.decode(SyncCode.self, from: data).exchange else {
            throw SyncError.failedToDecryptValue("Invalid recovery key in exchange response")
        }

        return exchangeKey
    }

    private func fetchEncryptedExchangeKey() async throws -> Data? {
        let url = endpoints.exchange.appendingPathComponent(exchangeInfo.keyId)

        let request = api.createRequest(url: url,
                                        method: .get,
                                        headers: [:],
                                        parameters: [:],
                                        body: nil,
                                        contentType: nil)

        do {
            let result = try await request.execute()
            guard let data = result.data else {
                throw SyncError.invalidDataInResponse("No body in successful GET on /exchange")
            }

            let encryptedRecoveryKeyString = try JSONDecoder
                .snakeCaseKeys
                .decode(ExchangeResult.self, from: data)
                .encryptedRecoveryKey

            guard let encrypted = encryptedRecoveryKeyString.data(using: .utf8) else {
                throw SyncError.invalidDataInResponse("unable to convert result string to data")
            }

            return Data(base64Encoded: encrypted)
        } catch SyncError.unexpectedStatusCode(let statusCode) {
            if statusCode == 404 {
                return nil
            }
            throw SyncError.unexpectedStatusCode(statusCode)
        }
    }

    struct ExchangeResult: Decodable {
        let encryptedRecoveryKey: String
    }

}

extension ExchangeInfo {

    func toCode() throws -> String {
        return try SyncCode(exchange: .init(keyId: keyId, publicKey: publicKey))
            .toJSON()
            .base64EncodedString()
    }

}
