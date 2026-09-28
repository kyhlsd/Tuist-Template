//
//  AccessTokenProviding.swift
//  Auth
//

/// 요청에 붙일 access token 과 401 뒤의 갱신을 제공한다. Networking 의 인증 미들웨어가 쓴다.
///
/// 앱의 구현은 `AuthSession` 이다.
public protocol AccessTokenProviding: Sendable {
    /// 지금 쓸 access token. 로그인 전이면 `nil`.
    func currentAccessToken() async throws -> String?
    /// 새 access token. `rejected` 는 401 을 받은 요청이 쓴 토큰이다.
    func refreshedAccessToken(rejected: String?) async throws -> String
}
