//
//  SessionToken.swift
//  Auth
//

/// 요청에 붙인 access token 과, 그 토큰을 읽은 세션의 세대.
///
/// 401 을 받은 요청이 이 값을 `refreshedAccessToken(rejected:)` 에 그대로 넘긴다. 요청을 보낸 뒤 로그인·로그아웃으로
/// 세션이 바뀌었으면 세대가 달라 갱신을 거절한다. 이전 세션의 요청이 새 세션의 토큰으로 다시 나가지 않게 한다.
/// 세대는 `AuthSession` 만 만든다.
public struct SessionToken: Equatable, Sendable {
    /// 요청에 붙일 access token. 로그인 전이면 `nil`.
    public let value: String?
    let generation: Int
}
