//
//  SessionStatus.swift
//  Domain
//

/// 로그인 세션의 상태.
public enum SessionStatus: Equatable, Sendable {
    /// 로그인되어 있다.
    case signedIn
    /// 로그인 전이거나 로그아웃했다.
    case signedOut
    /// 서버가 세션을 끝냈다. 다시 로그인해야 한다.
    case expired
}
