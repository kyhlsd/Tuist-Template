//
//  LoggingMiddlewareTests.swift
//  NetworkingTests
//

import Foundation
import HTTPTypes
@testable import Networking
import NetworkingTesting
import OpenAPIRuntime
import Testing

@Suite("LoggingMiddleware")
struct LoggingMiddlewareTests {
    private let baseURL = URL(filePath: "/api")
    private let operationID = "listItems"

    @Test("성공하면 status 와 request ID 가 담긴 요약을 하나 알린다")
    func intercept_success_reportsStatusAndRequestID() async throws {
        let observer = RecordingNetworkActivityObserver()
        let middleware = LoggingMiddleware(subsystem: "test", observer: observer)

        _ = try await middleware.intercept(
            request(path: "/items", requestID: "request-id"), body: nil, baseURL: baseURL,
            operationID: operationID, next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )

        let record = try #require(observer.records.only)
        #expect(record.statusCode == 200)
        #expect(record.failureSummary == nil)
        #expect(record.requestID == "request-id")
    }

    @Test("실패하면 실패 요약이 담긴 요약을 하나 알리고 에러를 다시 던진다")
    func intercept_failure_reportsSummaryAndRethrows() async throws {
        let observer = RecordingNetworkActivityObserver()
        let middleware = LoggingMiddleware(subsystem: "test", observer: observer)

        await #expect(throws: URLError.self) {
            try await middleware.intercept(
                request(path: "/items", requestID: nil), body: nil, baseURL: baseURL,
                operationID: operationID, next: { _, _, _ in throw URLError(.timedOut) }
            )
        }

        let record = try #require(observer.records.only)
        #expect(record.statusCode == nil)
        #expect(record.failureSummary == "URLError(\(URLError.Code.timedOut.rawValue))")
        #expect(record.requestID == nil)
    }

    @Test("취소로 끝나면 취소로 표시한 요약을 알린다", arguments: [CancellationKind.urlCancelled, .taskCancelled])
    private func intercept_cancellation_reportsCancellation(kind: CancellationKind) async throws {
        let observer = RecordingNetworkActivityObserver()
        let middleware = LoggingMiddleware(subsystem: "test", observer: observer)

        _ = try? await middleware.intercept(
            request(path: "/items", requestID: nil), body: nil, baseURL: baseURL,
            operationID: operationID, next: { _, _, _ in throw kind.error }
        )

        #expect(try #require(observer.records.only).isCancellation)
    }

    @Test("취소가 아닌 실패는 취소로 표시하지 않는다")
    func intercept_failure_isNotCancellation() async throws {
        let observer = RecordingNetworkActivityObserver()
        let middleware = LoggingMiddleware(subsystem: "test", observer: observer)

        _ = try? await middleware.intercept(
            request(path: "/items", requestID: nil), body: nil, baseURL: baseURL,
            operationID: operationID, next: { _, _, _ in throw URLError(.timedOut) }
        )

        #expect(try !#require(observer.records.only).isCancellation)
    }

    @Test("요약의 path 에는 쿼리가 없다")
    func intercept_pathWithQuery_reportsPathWithoutQuery() async throws {
        let observer = RecordingNetworkActivityObserver()
        let middleware = LoggingMiddleware(subsystem: "test", observer: observer)

        _ = try await middleware.intercept(
            request(path: "/items?cursor=abc", requestID: nil), body: nil, baseURL: baseURL,
            operationID: operationID, next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )

        #expect(observer.records.map(\.path) == ["/items"])
    }

    private func request(path: String, requestID: String?) -> HTTPRequest {
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: path)
        request.headerFields[NetworkDefaults.requestIDField] = requestID
        return request
    }
}

/// 취소 테스트의 인자. 에러는 Sendable 이 아니라서 종류만 넘기고 테스트 안에서 만든다.
private enum CancellationKind: Sendable {
    case urlCancelled
    case taskCancelled

    var error: any Error {
        switch self {
        case .urlCancelled:
            URLError(.cancelled)
        case .taskCancelled:
            CancellationError()
        }
    }
}

private extension Array {
    /// 원소가 정확히 하나면 그 원소, 아니면 `nil`.
    var only: Element? {
        count == 1 ? first : nil
    }
}
