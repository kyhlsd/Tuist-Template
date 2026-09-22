//
//  InMemoryTokenStore.swift
//  NetworkingTesting
//

import Networking

/// 메모리에만 토큰을 두는 `TokenStore`. 테스트에서 Keychain 대신 쓴다.
///
/// 검증용으로 `save`/`clear` 호출 횟수를 기록한다.
public actor InMemoryTokenStore: TokenStore {
    public private(set) var tokens: AuthTokens?
    public private(set) var saveCount = 0
    public private(set) var clearCount = 0

    public init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    public func load() async throws -> AuthTokens? {
        tokens
    }

    public func save(_ tokens: AuthTokens) async throws {
        self.tokens = tokens
        saveCount += 1
    }

    public func clear() async throws {
        tokens = nil
        clearCount += 1
    }
}
