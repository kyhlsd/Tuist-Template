//
//  RetryMiddlewareTests.swift
//  NetworkingTests
//

import Foundation
import HTTPTypes
@testable import Networking
import OpenAPIRuntime
import Testing

@Suite("RetryMiddleware")
struct RetryMiddlewareTests {
    private let baseURL = URL(filePath: "/api")
    private let operationID = "listItems"

    @Test("일시적 에러 뒤 성공하면 한 번 기다렸다가 성공 응답을 돌려준다")
    func intercept_transientErrorThenSuccess_retries() async throws {
        let next = ScriptedNext([.failure(transportError(.networkConnectionLost)), .success(.ok)])
        let sleeper = SleepRecorder()
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: sleeper.sleep)

        let (response, _) = try await middleware.intercept(
            request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .ok)
        #expect(await sleeper.delays.count == 1)
    }

    @Test("마지막 시도도 일시적 에러면 그 에러를 그대로 던진다")
    func intercept_transientErrorOnLastAttempt_rethrows() async {
        let next = ScriptedNext(Array(repeating: .failure(transportError(.cannotConnectToHost)), count: 3))
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        let error = await #expect(throws: ClientError.self) {
            try await middleware.intercept(
                request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
            )
        }
        #expect((error?.underlyingError as? URLError)?.code == .cannotConnectToHost)
        #expect(await next.callCount == 3)
    }

    @Test("타임아웃은 이미 충분히 기다린 결과이므로 다시 보내지 않는다")
    func intercept_timedOut_doesNotRetry() async {
        let next = ScriptedNext([.failure(transportError(.timedOut)), .success(.ok)])
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        let error = await #expect(throws: ClientError.self) {
            try await middleware.intercept(
                request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
            )
        }
        #expect((error?.underlyingError as? URLError)?.code == .timedOut)
        #expect(await next.callCount == 1)
    }

    @Test("504 는 게이트웨이가 이미 기다린 결과이므로 다시 보내지 않는다")
    func intercept_gatewayTimeout_doesNotRetry() async throws {
        let next = ScriptedNext([.success(.gatewayTimeout), .success(.ok)])
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        let (response, _) = try await middleware.intercept(
            request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .gatewayTimeout)
        #expect(await next.callCount == 1)
    }

    @Test("503 이 계속되면 최대 횟수만큼 지수 백오프로 다시 보낸다")
    func intercept_serviceUnavailable_retriesUpToMax() async throws {
        let next = ScriptedNext(Array(repeating: .success(.serviceUnavailable), count: 3))
        let sleeper = SleepRecorder()
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: sleeper.sleep)

        let (response, _) = try await middleware.intercept(
            request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .serviceUnavailable)
        #expect(await next.callCount == 3)
        #expect(await sleeper.delays == [.milliseconds(500), .seconds(1)])
    }

    @Test("멱등이 아닌 메서드는 다시 보내지 않는다")
    func intercept_postRequest_doesNotRetry() async throws {
        let next = ScriptedNext([.success(.serviceUnavailable), .success(.ok)])
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        let (response, _) = try await middleware.intercept(
            request(.post), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .serviceUnavailable)
        #expect(await next.callCount == 1)
    }

    @Test("취소는 다시 보내지 않고 그대로 던진다", arguments: [
        CancellationKind.urlCancelled,
        CancellationKind.taskCancelled,
    ])
    private func intercept_cancelled_doesNotRetry(kind: CancellationKind) async {
        let next = ScriptedNext([.failure(wrappedByRuntime(kind.error)), .success(.ok)])
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        await #expect(throws: (any Error).self) {
            try await middleware.intercept(
                request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
            )
        }
        #expect(await next.callCount == 1)
    }

    @Test("일시적이지 않은 상태는 다시 보내지 않는다")
    func intercept_clientError_doesNotRetry() async throws {
        let next = ScriptedNext([.success(.notFound), .success(.ok)])
        let middleware = RetryMiddleware(maxRetries: 2, baseDelay: .milliseconds(500), sleep: { _ in })

        let (response, _) = try await middleware.intercept(
            request(.get), body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .notFound)
        #expect(await next.callCount == 1)
    }

    private func request(_ method: HTTPRequest.Method) -> HTTPRequest {
        HTTPRequest(method: method, scheme: nil, authority: nil, path: "/items")
    }

    private func transportError(_ code: URLError.Code) -> ClientError {
        wrappedByRuntime(URLError(code))
    }

    /// 런타임은 transport 에러를 `ClientError` 로 감싸서 미들웨어의 `next` 밖으로 던진다. 같은 모양을 만든다.
    private func wrappedByRuntime(_ error: any Error) -> ClientError {
        ClientError(
            operationID: operationID,
            operationInput: operationID,
            causeDescription: "Transport threw an error.",
            underlyingError: error
        )
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

/// `next` 대역. 정해진 결과를 차례로 돌려주고 호출 횟수를 센다.
private actor ScriptedNext {
    private var results: [Result<HTTPResponse.Status, any Error>]
    private(set) var callCount = 0

    init(_ results: [Result<HTTPResponse.Status, any Error>]) {
        self.results = results
    }

    nonisolated var call: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) {
        { _, _, _ in try await self.next() }
    }

    private func next() throws -> (HTTPResponse, HTTPBody?) {
        callCount += 1
        return try (HTTPResponse(status: results.removeFirst().get()), nil)
    }
}

/// 주입된 sleep 이 받은 지연값을 기록한다. 실제로 기다리지 않는다.
private actor SleepRecorder {
    private(set) var delays: [Duration] = []

    nonisolated var sleep: RetryMiddleware.Sleep {
        { await self.record($0) }
    }

    private func record(_ delay: Duration) {
        delays.append(delay)
    }
}
