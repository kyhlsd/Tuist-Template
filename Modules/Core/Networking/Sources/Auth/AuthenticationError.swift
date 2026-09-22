//
//  AuthenticationError.swift
//  Networking
//

/// 토큰 갱신의 실패.
public enum AuthenticationError: Error, Equatable, Sendable {
    /// refresh token 이 없거나 서버가 거절했다. 저장된 토큰은 지워졌다.
    case sessionExpired
    /// 서버가 명세에 없는 응답을 돌려주었다. 저장된 토큰은 그대로다.
    case refreshFailed
}
