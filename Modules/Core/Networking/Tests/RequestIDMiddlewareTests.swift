//
//  RequestIDMiddlewareTests.swift
//  NetworkingTests
//

import Foundation
import HTTPTypes
@testable import Networking
import OpenAPIRuntime
import Testing

@Suite("RequestIDMiddleware")
struct RequestIDMiddlewareTests {
    private let baseURL = URL(filePath: "/api")
    private let operationID = "listItems"
    private let middleware = RequestIDMiddleware(makeID: { "generated-id" })

    @Test("요청에 헤더가 없으면 새 ID 를 붙인다")
    func intercept_requestWithoutID_addsGeneratedID() async throws {
        let next = CapturingNext(response: HTTPResponse(status: .ok))

        _ = try await middleware.intercept(
            request(), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(await next.requestID == "generated-id")
    }

    @Test("요청에 헤더가 있으면 그 값을 유지한다")
    func intercept_requestWithID_keepsExistingID() async throws {
        let next = CapturingNext(response: HTTPResponse(status: .ok))

        _ = try await middleware.intercept(
            request(id: "existing-id"), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(await next.requestID == "existing-id")
    }

    @Test("응답에 헤더가 없으면 요청과 같은 ID 를 붙인다")
    func intercept_responseWithoutID_addsRequestID() async throws {
        let next = CapturingNext(response: HTTPResponse(status: .ok))

        let (response, _) = try await middleware.intercept(
            request(id: "existing-id"), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.headerFields[NetworkDefaults.requestIDField] == "existing-id")
    }

    @Test("응답에 헤더가 있으면 그 값을 유지한다")
    func intercept_responseWithID_keepsResponseID() async throws {
        var headers = HTTPFields()
        headers[NetworkDefaults.requestIDField] = "server-id"
        let next = CapturingNext(response: HTTPResponse(status: .ok, headerFields: headers))

        let (response, _) = try await middleware.intercept(
            request(), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.headerFields[NetworkDefaults.requestIDField] == "server-id")
    }

    @Test("에러는 그대로 다시 던진다")
    func intercept_nextThrows_rethrows() async {
        let error = await #expect(throws: URLError.self) {
            try await middleware.intercept(
                request(), body: nil, baseURL: baseURL, operationID: operationID,
                next: { _, _, _ in throw URLError(.timedOut) }
            )
        }
        #expect(error?.code == .timedOut)
    }

    private func request(id: String? = nil) -> HTTPRequest {
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/items")
        request.headerFields[NetworkDefaults.requestIDField] = id
        return request
    }
}

/// `next` 대역. 받은 요청의 request ID 를 기록하고 정해진 응답을 돌려준다.
private actor CapturingNext {
    private let response: HTTPResponse
    private(set) var requestID: String?

    init(response: HTTPResponse) {
        self.response = response
    }

    nonisolated var call: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) {
        { request, _, _ in await self.capture(request) }
    }

    private func capture(_ request: HTTPRequest) -> (HTTPResponse, HTTPBody?) {
        requestID = request.headerFields[NetworkDefaults.requestIDField]
        return (response, nil)
    }
}
