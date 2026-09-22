//
//  RetryMiddleware.swift
//  Networking
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// 멱등 요청이 일시적으로 실패하면 지수 백오프로 다시 보낸다.
///
/// 재시도 조건: 멱등 메서드이고, body 를 다시 읽을 수 있고, 연결 끊김·호스트 연결 실패이거나
/// 502/503 응답일 때. 취소는 재시도하지 않는다. 마지막 시도의 결과를 그대로 돌려준다.
///
/// 타임아웃은 재시도하지 않는다. 클라이언트의 `.timedOut` 과 게이트웨이의 504 모두 이미 타임아웃만큼
/// 기다린 결과라서 다시 보내면 대기 시간만 몇 배로 늘어난다(예: 게이트웨이 29초 × 3회 ≈ 88초).
struct RetryMiddleware: ClientMiddleware {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let maxRetries: Int
    private let baseDelay: Duration
    private let sleep: Sleep

    init(
        maxRetries: Int,
        baseDelay: Duration,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.sleep = sleep
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let isReplayable = body.map { $0.iterationBehavior == .multiple } ?? true
        guard Self.idempotentMethods.contains(request.method), isReplayable else {
            return try await next(request, body, baseURL)
        }

        var attempt = 0
        while true {
            try Task.checkCancellation()
            let isLastAttempt = attempt >= maxRetries
            do {
                let (response, responseBody) = try await next(request, body, baseURL)
                if isLastAttempt || !Self.transientStatuses.contains(response.status) {
                    return (response, responseBody)
                }
            } catch where !isLastAttempt && Self.isTransient(error) {
                // 아래에서 기다린 뒤 다시 보낸다.
            }
            try await sleep(baseDelay * (1 << attempt))
            attempt += 1
        }
    }

    private static let idempotentMethods: Set<HTTPRequest.Method> = [.get, .head, .put, .delete]
    private static let transientStatuses: Set<HTTPResponse.Status> = [.badGateway, .serviceUnavailable]
    private static let transientErrors: Set<URLError.Code> = [.networkConnectionLost, .cannotConnectToHost]

    /// 런타임은 transport 에러를 `ClientError` 로 감싸서 `next` 밖으로 던진다. 원래 에러를 꺼내 판단한다.
    private static func isTransient(_ error: any Error) -> Bool {
        let underlying = (error as? ClientError)?.underlyingError ?? error
        guard let urlError = underlying as? URLError else {
            return false
        }
        return transientErrors.contains(urlError.code)
    }
}
