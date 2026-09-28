//
//  APIClientFactory.swift
//  Networking
//

import Auth
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// 생성된 `Client` 에 미들웨어를 붙여 조립한다. App 만 호출한다.
///
/// 미들웨어는 앞쪽이 바깥쪽이다: RequestID → Logging → Retry → Auth → transport.
/// RequestID 가 가장 바깥이라 Logging 이 ID 를 보고, 재시도는 같은 ID 를 공유한다.
/// Auth 가 Retry 안쪽에 있어서 재시도할 때마다 최신 토큰이 다시 붙는다.
public enum APIClientFactory {
    /// 앱 수명 동안 하나만 만들어 쓰는 세션. `URLSession.shared` 는 설정을 바꿀 수 없다.
    public static func makeSession() -> URLSession {
        URLSession(configuration: NetworkDefaults.makeSessionConfiguration())
    }

    /// `AuthSession` 에 넘길 refresh 호출을 만든다.
    ///
    /// refresh 요청은 AuthMiddleware 를 타지 않는 별도 클라이언트로 보낸다. 재귀를 막는다.
    /// - Parameters:
    ///   - logSubsystem: 요청 로그의 subsystem. 보통 앱의 번들 ID.
    ///   - activityObserver: refresh 요청이 끝날 때마다 요약을 받는다.
    public static func makeTokenRefresh(
        baseURL: URL,
        session: URLSession,
        logSubsystem: String,
        activityObserver: any NetworkActivityObserving
    ) -> AuthSession.Refresh {
        let refreshClient = Client(
            serverURL: baseURL,
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                RequestIDMiddleware(),
                LoggingMiddleware(subsystem: logSubsystem, observer: activityObserver),
            ]
        )
        return { refreshToken in
            try await refreshTokens(using: refreshClient, refreshToken: refreshToken)
        }
    }

    /// - Parameters:
    ///   - authSession: 요청에 붙일 토큰과 401 갱신을 맡는다. refresh 호출은 `makeTokenRefresh` 로 만든 것을 넣는다.
    ///   - logSubsystem: 요청 로그의 subsystem. 보통 앱의 번들 ID.
    ///   - activityObserver: 요청이 끝날 때마다 요약을 받는다.
    public static func make(
        baseURL: URL,
        session: URLSession,
        authSession: AuthSession,
        logSubsystem: String,
        activityObserver: any NetworkActivityObserving
    ) -> any APIProtocol {
        Client(
            serverURL: baseURL,
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                RequestIDMiddleware(),
                LoggingMiddleware(subsystem: logSubsystem, observer: activityObserver),
                RetryMiddleware(maxRetries: NetworkDefaults.maxRetries, baseDelay: NetworkDefaults.retryBaseDelay),
                AuthMiddleware(session: authSession, publicOperationIDs: PublicOperation.ids),
            ]
        )
    }

    /// refresh 응답을 토큰 또는 인증 에러로 바꾼다.
    ///
    /// 전송 실패는 그대로 던진다(토큰 유지). 서버가 거절(400/401)하면 `sessionExpired`(토큰 삭제),
    /// 명세에 없는 응답(5xx 등)이면 `refreshFailed`(토큰 유지). 이 구분이 로그아웃 여부를 정한다.
    static func refreshTokens(using client: any APIProtocol, refreshToken: String) async throws -> AuthTokens {
        let output = try await client.refreshToken(body: .json(.init(refreshToken: refreshToken)))
        switch output {
        case let .ok(ok):
            // 지금 명세의 본문은 JSON 하나뿐이라 던지지 않는다. 콘텐츠 타입이 늘면 JSON 이 아닌 본문이 여기로 온다.
            guard let pair = try? ok.body.json else {
                throw AuthenticationError.refreshFailed
            }
            return AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
        case .unauthorized, .badRequest:
            throw AuthenticationError.sessionExpired
        case .undocumented:
            throw AuthenticationError.refreshFailed
        }
    }
}
