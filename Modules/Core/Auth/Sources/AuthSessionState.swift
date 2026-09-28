//
//  AuthSessionState.swift
//  Auth
//

/// `SessionManaging.states()` 가 알리는 세션 상태.
///
/// 프로토콜 대역이 `AuthSession` 에 묶이지 않도록 최상위 타입으로 둔다. `AuthSession.State` 로도 부를 수 있다.
public enum AuthSessionState: Equatable, Sendable {
    /// 토큰이 있다. 로그인했거나 앱 시작 때 저장된 토큰을 찾았다.
    case signedIn
    /// 토큰이 없다. 로그인 전이거나 로그아웃했다.
    case signedOut
    /// 서버가 refresh token 을 거절해 토큰을 지웠다. 다시 로그인해야 한다.
    case expired
}

public extension AuthSession {
    typealias State = AuthSessionState
}
