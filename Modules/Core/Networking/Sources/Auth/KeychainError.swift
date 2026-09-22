//
//  KeychainError.swift
//  Networking
//

import Security

/// `KeychainTokenStore` 의 실패.
public enum KeychainError: Error, Equatable, Sendable {
    /// `SecItem*` 가 예상하지 못한 상태를 돌려주었다.
    case unexpectedStatus(OSStatus)
    /// 저장된 값을 토큰으로 해석할 수 없다.
    case invalidData
}
