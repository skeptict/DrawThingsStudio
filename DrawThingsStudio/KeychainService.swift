//
//  KeychainService.swift
//  DrawThingsStudio
//
//  Stores sensitive settings values in the macOS Keychain.
//

import Foundation
import Security

protocol KeychainService {
    func string(for account: String) -> String?
    func set(_ value: String, for account: String) -> Bool
    func removeValue(for account: String) -> Bool
}

final class MacKeychainService: KeychainService {
    private let service: String

    init(service: String = "DrawThingsStudio") {
        self.service = service
    }

    func string(for account: String) -> String? {
        let query = baseQuery(for: account).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    func set(_ value: String, for account: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(for: account)

        let updateAttributes = [kSecValueData as String: data] as CFDictionary
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            _ = SecItemDelete(query as CFDictionary)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func removeValue(for account: String) -> Bool {
        let status = SecItemDelete(baseQuery(for: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
