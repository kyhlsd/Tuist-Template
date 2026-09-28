//
//  SessionManaging.swift
//  Auth
//

/// 로그인·로그아웃으로 세션을 바꾸고 상태를 알린다. Data 의 `RemoteAuthRepository` 가 쓴다.
///
/// 앱의 구현은 `AuthSession` 이다. 인증 미들웨어(`AccessTokenProviding`)와 같은 인스턴스여야 한다.
public protocol SessionManaging: Sendable {
    func signIn(with tokens: AuthTokens) async throws
    func signOut() async throws
    /// 구독마다 따로 만드는 상태 스트림. 첫 값은 현재 상태다.
    func states() async -> AsyncStream<AuthSessionState>
}
