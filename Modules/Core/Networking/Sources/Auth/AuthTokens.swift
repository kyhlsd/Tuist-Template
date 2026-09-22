//
//  AuthTokens.swift
//  Networking
//

/// 앱이 보관하는 인증 토큰 한 쌍.
///
/// 생성 타입 `Components.Schemas.TokenPair` 와 분리한 내부 모델이다.
/// 명세가 바뀌어도 저장 형식과 미들웨어는 영향받지 않는다.
public struct AuthTokens: Sendable, Equatable, Codable {
    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
