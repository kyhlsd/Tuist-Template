//
//  FailingTokenStore.swift
//  AuthTesting
//

import Auth

/// 저장·삭제를 실패시킬 수 있는 `TokenStore`. 저장은 처음 `saveFailures` 번만 실패하고, 삭제는 `failsClear` 면 늘 실패한다.
///
/// 실패는 `FailingTokenStore.Failure` 로 던진다. Auth 와 Data 테스트가 함께 쓴다.
public actor FailingTokenStore: TokenStore {
    /// 이 저장소가 던지는 실패.
    public struct Failure: Error, Equatable {
        public init() {}
    }

    public private(set) var tokens: AuthTokens?
    private var saveFailures: Int
    private let failsClear: Bool

    public init(tokens: AuthTokens?, saveFailures: Int = 0, failsClear: Bool = false) {
        self.tokens = tokens
        self.saveFailures = saveFailures
        self.failsClear = failsClear
    }

    public func load() async throws -> AuthTokens? {
        tokens
    }

    public func save(_ tokens: AuthTokens) async throws {
        if saveFailures > 0 {
            saveFailures -= 1
            throw Failure()
        }
        self.tokens = tokens
    }

    public func clear() async throws {
        if failsClear {
            throw Failure()
        }
        tokens = nil
    }
}
