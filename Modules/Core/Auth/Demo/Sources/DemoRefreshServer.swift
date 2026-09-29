//
//  DemoRefreshServer.swift
//  AuthDemo
//

import Auth
import Foundation

/// 갱신 요청에 `mode` 대로 응답하는 가짜 서버.
///
/// `AuthSession.Refresh` 는 `@Sendable` 이라 가변 상태를 직접 캡처할 수 없다. 모드를 이 actor 에 두고 클로저가 actor 를 캡처한다.
actor DemoRefreshServer {
    enum Mode: CaseIterable, Hashable, Sendable {
        /// 새 토큰을 돌려준다.
        case success
        /// refresh token 을 거절한다(`AuthenticationError.sessionExpired`).
        case expired
        /// 일시적으로 실패한다(`AuthenticationError.refreshFailed`).
        case failure
    }

    private var mode: Mode = .success

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    func refresh(_: String) throws -> AuthTokens {
        switch mode {
        case .success:
            Self.issueTokens()
        case .expired:
            throw AuthenticationError.sessionExpired
        case .failure:
            throw AuthenticationError.refreshFailed
        }
    }

    /// 로그인·갱신 응답으로 쓰는 새 토큰. 화면에서 바뀐 것을 알아볼 수 있게 UUID 앞부분을 붙인다.
    nonisolated static func issueTokens() -> AuthTokens {
        AuthTokens(
            accessToken: TokenPrefix.access + uniqueSuffix(),
            refreshToken: TokenPrefix.refresh + uniqueSuffix()
        )
    }

    private nonisolated static func uniqueSuffix() -> String {
        String(UUID().uuidString.prefix(TokenPrefix.suffixLength))
    }
}

private enum TokenPrefix {
    static let access = "access-"
    static let refresh = "refresh-"
    static let suffixLength = 8
}
