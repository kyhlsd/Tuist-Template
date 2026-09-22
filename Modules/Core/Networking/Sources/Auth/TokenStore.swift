//
//  TokenStore.swift
//  Networking
//

/// 인증 토큰 저장소.
///
/// 앱은 `KeychainTokenStore` 를, 테스트는 `NetworkingTesting` 의 `InMemoryTokenStore` 를 쓴다.
public protocol TokenStore: Sendable {
    /// 저장된 토큰. 없으면 `nil`.
    func load() async throws -> AuthTokens?
    func save(_ tokens: AuthTokens) async throws
    /// 저장된 토큰을 지운다. 토큰이 없어도 성공한다.
    func clear() async throws
}
