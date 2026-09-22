//
//  KeychainTokenStore.swift
//  Networking
//

import Foundation
import Security

/// Keychain 에 토큰을 저장하는 `TokenStore`.
///
/// 두 토큰을 JSON 하나로 묶어 generic password 항목 1개에 둔다.
/// `AfterFirstUnlockThisDeviceOnly` 라 백그라운드에서도 읽을 수 있고,
/// 기기 백업으로 다른 기기에 넘어가지 않는다.
public struct KeychainTokenStore: TokenStore {
    private let service: String

    /// - Parameter service: Keychain 항목의 서비스 이름. 보통 앱의 번들 ID.
    public init(service: String) {
        self.service = service
    }

    public func load() async throws -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            do {
                return try JSONDecoder().decode(AuthTokens.self, from: data)
            } catch {
                throw KeychainError.invalidData
            }
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func save(_ tokens: AuthTokens) async throws {
        let data = try JSONEncoder().encode(tokens)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addQuery = baseQuery.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    public func clear() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        // 지울 항목이 없으면 이미 원하는 상태이므로 성공으로 본다.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Account.tokens,
        ]
    }
}

private enum Account {
    static let tokens = "authTokens"
}
