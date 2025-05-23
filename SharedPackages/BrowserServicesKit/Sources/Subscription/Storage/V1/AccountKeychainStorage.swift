//
//  AccountKeychainStorage.swift
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

public enum AccountKeychainAccessType: String {
    case getAuthToken
    case storeAuthToken
    case getAccessToken
    case storeAccessToken
    case getEmail
    case storeEmail
    case getExternalID
    case storeExternalID
    case clearAuthenticationData
}

public enum AccountKeychainAccessError: Error, LocalizedError {
    case failedToDecodeKeychainData
    case failedToDecodeKeychainValueAsData
    case failedToDecodeKeychainDataAsString
    case keychainSaveFailure(OSStatus)
    case keychainDeleteFailure(OSStatus)
    case keychainLookupFailure(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .failedToDecodeKeychainData: return "failedToDecodeKeychainData"
        case .failedToDecodeKeychainValueAsData: return "failedToDecodeKeychainValueAsData"
        case .failedToDecodeKeychainDataAsString: return "failedToDecodeKeychainDataAsString"
        case .keychainSaveFailure(let status): return "keychainSaveFailure(\(status))"
        case .keychainDeleteFailure(let status): return "keychainDeleteFailure(\(status))"
        case .keychainLookupFailure(let status): return "keychainLookupFailure(\(status))"
        }
    }

    public var localizedDescription: String {
        errorDescription ?? "Unknown"
    }
}

public final class AccountKeychainStorage: AccountStoring {

    public init() {}

    public func getAuthToken() throws -> String? {
        try getString(forField: .authToken)
    }

    public func store(authToken: String) throws {
        try set(string: authToken, forField: .authToken)
    }

    public func getEmail() throws -> String? {
        try getString(forField: .email)
    }

    public func getExternalID() throws -> String? {
        try getString(forField: .externalID)
    }

    public func store(externalID: String?) throws {
        if let externalID = externalID, !externalID.isEmpty {
            try set(string: externalID, forField: .externalID)
        } else {
            try deleteItem(forField: .externalID)
        }
    }

    public func store(email: String?) throws {
        if let email = email, !email.isEmpty {
            try set(string: email, forField: .email)
        } else {
            try deleteItem(forField: .email)
        }
    }

    public func clearAuthenticationState() throws {
        try deleteItem(forField: .authToken)
        try deleteItem(forField: .email)
        try deleteItem(forField: .externalID)
    }
}

extension AccountKeychainStorage {

    /*
     Uses just kSecAttrService as the primary key, since we don't want to store
     multiple accounts/tokens at the same time
    */
    enum AccountKeychainField: String, CaseIterable {
        case authToken = "account.authToken"
        case email = "account.email"
        case externalID = "account.external_id"

        var keyValue: String {
            (Bundle.main.bundleIdentifier ?? "com.duckduckgo") + "." + rawValue
        }
    }

    func getString(forField field: AccountKeychainField) throws -> String? {
        guard let data = try retrieveData(forField: field) else {
            return nil
        }

        if let decodedString = String(data: data, encoding: String.Encoding.utf8) {
            return decodedString
        } else {
            throw AccountKeychainAccessError.failedToDecodeKeychainDataAsString
        }
    }

    func retrieveData(forField field: AccountKeychainField, useDataProtectionKeychain: Bool = true) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrService as String: field.keyValue,
            kSecReturnData as String: true,
            kSecUseDataProtectionKeychain as String: useDataProtectionKeychain
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            if let existingItem = item as? Data {
                return existingItem
            } else {
                throw AccountKeychainAccessError.failedToDecodeKeychainValueAsData
            }
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw AccountKeychainAccessError.keychainLookupFailure(status)
        }
    }

    func set(string: String, forField field: AccountKeychainField) throws {
        guard let stringData = string.data(using: .utf8) else {
            return
        }

        try deleteItem(forField: field)
        try store(data: stringData, forField: field)
    }

    func store(data: Data, forField field: AccountKeychainField, useDataProtectionKeychain: Bool = true) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrSynchronizable: false,
            kSecAttrService: field.keyValue,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: useDataProtectionKeychain] as [String: Any]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw AccountKeychainAccessError.keychainSaveFailure(status)
        }
    }

    func deleteItem(forField field: AccountKeychainField, useDataProtectionKeychain: Bool = true) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: field.keyValue,
            kSecUseDataProtectionKeychain as String: useDataProtectionKeychain]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw AccountKeychainAccessError.keychainDeleteFailure(status)
        }
    }
}
