//
//  AccessTokenProviding.swift
//  Auth
//

/// 요청에 붙일 access token 과 401 뒤의 갱신을 제공한다. Networking 의 인증 미들웨어가 쓴다.
///
/// 앱의 구현은 `AuthSession` 이다.
public protocol AccessTokenProviding: Sendable {
    /// 지금 쓸 access token 과 그것을 읽은 세션. 로그인 전이면 `value` 가 `nil`.
    func currentAccessToken() async throws -> SessionToken
    /// 새 access token. `rejected` 는 401 을 받은 요청이 `currentAccessToken()` 에서 받은 값 그대로다.
    func refreshedAccessToken(rejected: SessionToken) async throws -> String
}
