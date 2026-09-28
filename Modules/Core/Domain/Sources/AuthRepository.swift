//
//  AuthRepository.swift
//  Domain
//

/// 로그인 세션 저장소.
///
/// Domain 은 프로토콜만 선언한다. 구현은 Data 의 `RemoteAuthRepository`,
/// 테스트·데모용 스텁은 DomainTesting 의 `StubAuthRepository` 다.
/// 어떤 구현을 쓸지는 App 이 정한다.
public protocol AuthRepository: Sendable {
    /// 자격 증명으로 로그인하고 받은 토큰을 보관한다. 성공하면 `sessionStatuses()` 에 `.signedIn` 이 온다.
    func signIn(email: String, password: String) async throws(AuthError)
    /// 보관한 토큰을 지운다. 서버 호출은 없다. 실패해도 `sessionStatuses()` 에는 `.signedOut` 이 온다.
    func signOut() async throws(AuthError)
    /// 세션 상태 스트림. 첫 값은 현재 상태이고, 이후 바뀔 때마다 값이 온다.
    /// 구독마다 따로 스트림을 받는다. 구독을 끝내려면 순회하는 Task 를 취소한다.
    func sessionStatuses() async -> AsyncStream<SessionStatus>
}
