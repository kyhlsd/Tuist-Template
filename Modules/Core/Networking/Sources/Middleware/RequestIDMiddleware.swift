//
//  RequestIDMiddleware.swift
//  Networking
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// 요청마다 `X-Request-ID` 헤더를 붙여 클라이언트 로그와 서버 로그를 잇는다.
///
/// 가장 바깥에 두어 Logging 이 ID 를 보고, 재시도는 같은 ID 를 공유한다.
/// 응답에도 같은 값을 넣는다. 런타임의 `ClientError.request` 는 미들웨어가 붙이기 전의 요청이라
/// 호출부는 응답(`ClientError.response`)에서만 ID 를 읽을 수 있기 때문이다.
///
/// - Important: 응답 헤더의 값은 서버가 돌려준 것이 아니라 클라이언트가 넣은 것일 수 있다.
struct RequestIDMiddleware: ClientMiddleware {
    private let makeID: @Sendable () -> String

    /// - Parameter makeID: 새 request ID 를 만든다. 테스트에서 고정값을 넣는다.
    init(makeID: @escaping @Sendable () -> String = { UUID().uuidString }) {
        self.makeID = makeID
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        let requestID: String
        if let existing = request.headerFields[NetworkDefaults.requestIDField] {
            requestID = existing
        } else {
            requestID = makeID()
            request.headerFields[NetworkDefaults.requestIDField] = requestID
        }

        var (response, responseBody) = try await next(request, body, baseURL)
        if response.headerFields[NetworkDefaults.requestIDField] == nil {
            response.headerFields[NetworkDefaults.requestIDField] = requestID
        }
        return (response, responseBody)
    }
}
