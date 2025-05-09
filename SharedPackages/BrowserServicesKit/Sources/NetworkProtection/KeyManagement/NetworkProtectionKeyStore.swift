//
//  NetworkProtectionKeyStore.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import os.log

public protocol NetworkProtectionKeyStore {

    /// Obtain the current expiration date
    ///
    var currentExpirationDate: Date? { get }

    /// Obtain the current `KeyPair`.
    ///
    func currentKeyPair() -> KeyPair?

    /// Create a new `KeyPair`.
    ///
    func newKeyPair() -> KeyPair

    /// Sets the validity interval for keys
    ///
    func setValidityInterval(_ validityInterval: TimeInterval?)

    /// Updates the existing KeyPair.
    ///
    func updateKeyPair(_ newKeyPair: KeyPair)

    /// Resets the current `KeyPair` so a new one will be generated when requested.
    ///
    func resetCurrentKeyPair()
}

/// Generates and stores instances of a PrivateKey on behalf of the user. This key is used to derive a PublicKey which is then used for registration with the Network Protection backend servers.
/// The key is reused between servers (that is, each user currently gets a single key), though this will change in the future to periodically refresh the key.
public final class NetworkProtectionKeychainKeyStore: NetworkProtectionKeyStore {
    private let keychainStore: NetworkProtectionKeychainStore
    private let userDefaults: UserDefaults
    private let errorEvents: EventMapping<NetworkProtectionError>?

    private struct Defaults {
        static let label = "DuckDuckGo Network Protection Private Key"
        static let service = "\(Bundle.main.bundleIdentifier!).privateKey"
        static let validityInterval = TimeInterval.day
    }

    private enum UserDefaultKeys {
        static let expirationDate = "com.duckduckgo.network-protection.KeyPair.UserDefaultKeys.expirationDate"
        static let currentPublicKey = "com.duckduckgo.network-protection.NetworkProtectionKeychainStore.UserDefaultKeys.currentPublicKeyBase64"
    }

    public init(keychainType: KeychainType,
                userDefaults: UserDefaults = .standard,
                errorEvents: EventMapping<NetworkProtectionError>?) {

        keychainStore = NetworkProtectionKeychainStore(label: Defaults.label,
                                                       serviceName: Defaults.service,
                                                       keychainType: keychainType)
        self.userDefaults = userDefaults
        self.errorEvents = errorEvents
    }

    // MARK: - NetworkProtectionKeyStore

    public func currentKeyPair() -> KeyPair? {
        Logger.networkProtectionKeyManagement.log("Querying the current key pair (publicKey: \(String(describing: self.currentPublicKey), privacy: .public), expirationDate: \(String(describing: self.currentExpirationDate), privacy: .public))")

        guard let currentPrivateKey = currentPrivateKey else {
            Logger.networkProtectionKeyManagement.log("There's no current private key.")
            return nil
        }

        guard let currentExpirationDate = currentExpirationDate,
              Date().addingTimeInterval(validityInterval) >= currentExpirationDate else {

            Logger.networkProtectionKeyManagement.log("The expirationDate date is missing, or we're past it (now: \(String(describing: Date()), privacy: .public), expirationDate: \(String(describing: self.currentExpirationDate), privacy: .public))")
            return nil
        }

        return KeyPair(privateKey: currentPrivateKey, expirationDate: currentExpirationDate)
    }

    public func newKeyPair() -> KeyPair {
        let newPrivateKey = PrivateKey()
        let newExpirationDate = Date().addingTimeInterval(validityInterval)

        return KeyPair(privateKey: newPrivateKey, expirationDate: newExpirationDate)
    }

    private var validityInterval = Defaults.validityInterval

    public func setValidityInterval(_ validityInterval: TimeInterval?) {
#if DEBUG
        self.validityInterval = validityInterval ?? Defaults.validityInterval
#else
        // No-op
#endif
    }

    private func newCurrentKeyPair() -> KeyPair {
        let currentPrivateKey = PrivateKey()
        let currentExpirationDate = Date().addingTimeInterval(validityInterval)

        self.currentPrivateKey = currentPrivateKey
        self.currentExpirationDate = currentExpirationDate

        return KeyPair(privateKey: currentPrivateKey, expirationDate: currentExpirationDate)
    }

    public func updateKeyPair(_ newKeyPair: KeyPair) {
        if currentPrivateKey != newKeyPair.privateKey {
            self.currentPrivateKey = newKeyPair.privateKey
        }

        if currentExpirationDate != newKeyPair.expirationDate {
            self.currentExpirationDate = newKeyPair.expirationDate
        }
    }

    public func resetCurrentKeyPair() {
        Logger.networkProtection.log("Resetting the current key pair")
        do {
            /// Besides resetting the current keyPair we'll remove all keychain entries associated with our service, since only one keychain entry
            /// should exist at once.
            try keychainStore.deleteAll()

            self.currentPublicKey = nil
            self.currentExpirationDate = nil
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }
    }

    // MARK: - UserDefaults

    public var currentExpirationDate: Date? {
        get {
            return userDefaults.object(forKey: UserDefaultKeys.expirationDate) as? Date
        }

        set {
            userDefaults.set(newValue, forKey: UserDefaultKeys.expirationDate)
        }
    }

    /// The currently used public key.
    ///
    /// The key is stored in base64 representation.
    ///
    private var currentPublicKey: String? {
        get {
            guard let base64Key = userDefaults.string(forKey: UserDefaultKeys.currentPublicKey) else {
                return nil
            }

            return PublicKey(base64Key: base64Key)?.base64Key
        }

        set {
            userDefaults.set(newValue, forKey: UserDefaultKeys.currentPublicKey)
        }
    }

    private var currentPrivateKey: PrivateKey? {
        get {
            guard let currentPublicKey = currentPublicKey else {
                return nil
            }

            do {
                guard let data = try keychainStore.readData(named: currentPublicKey) else {
                    return nil
                }

                return PrivateKey(rawValue: data)
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }

            return nil
        }

        set {
            do {
                try keychainStore.deleteAll()
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }

            guard let newValue = newValue else {
                return
            }

            do {
                currentPublicKey = newValue.publicKey.base64Key
                try keychainStore.writeData(newValue.rawValue, named: newValue.publicKey.base64Key)
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }
        }
    }

    // MARK: - EventMapping

    private func handle(_ error: Error) {
        Logger.networkProtectionKeyManagement.error("Failed to perform operation: \(error, privacy: .public)")

        guard let error = error as? NetworkProtectionKeychainStoreError else {
            assertionFailure("Failed to cast Network Protection Keychain store error")
            Logger.networkProtection.fault("Failed to cast Network Protection Keychain store error")
            errorEvents?.fire(NetworkProtectionError.unhandledError(function: #function, line: #line, error: error))
            return
        }

        errorEvents?.fire(error.networkProtectionError)
    }
}
