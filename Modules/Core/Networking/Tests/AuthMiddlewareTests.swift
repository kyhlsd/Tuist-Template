//
//  AuthMiddlewareTests.swift
//  NetworkingTests
//

import Foundation
import HTTPTypes
@testable import Networking
import NetworkingTesting
import OpenAPIRuntime
import Testing

@Suite("AuthMiddleware")
struct AuthMiddlewareTests {
    private let oldTokens = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh")
    private let newTokens = AuthTokens(accessToken: "new-access", refreshToken: "new-refresh")
    private let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/items")
    private let baseURL = URL(filePath: "/api")
    private let protectedOperation = "listItems"

    @Test("저장된 토큰을 Bearer 헤더로 붙인다")
    func intercept_withToken_attachesBearerHeader() async throws {
        let next = RecordingNext(statuses: [.ok])
        let middleware = makeMiddleware(store: InMemoryTokenStore(tokens: oldTokens))

        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: protectedOperation, next: next.call
        )

        #expect(await next.authorizations == ["Bearer old-access"])
    }

    @Test("저장된 토큰이 없으면 헤더 없이 보낸다")
    func intercept_withoutToken_sendsWithoutHeader() async throws {
        let next = RecordingNext(statuses: [.ok])
        let middleware = makeMiddleware(store: InMemoryTokenStore())

        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: protectedOperation, next: next.call
        )

        #expect(await next.authorizations == [nil])
    }

    @Test("토큰 없이 보낸 요청이 401 이면 갱신하지 않고 세션 만료로 끝난다")
    func intercept_withoutTokenUnauthorized_throwsSessionExpired() async {
        let next = RecordingNext(statuses: [.unauthorized, .ok])
        let refreshCount = CallCounter()
        let refresher = TokenRefresher(
            store: InMemoryTokenStore(),
            refresh: { [newTokens] _ in
                await refreshCount.increment()
                return newTokens
            },
            onSessionExpired: {}
        )
        let middleware = AuthMiddleware(refresher: refresher, publicOperationIDs: PublicOperation.ids)

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await middleware.intercept(
                request, body: nil, baseURL: baseURL, operationID: protectedOperation, next: next.call
            )
        }
        #expect(await next.callCount == 1)
        #expect(await refreshCount.value == 0)
    }

    @Test("공개 operation 에는 헤더를 붙이지 않는다", arguments: ["login", "refreshToken"])
    func intercept_publicOperation_doesNotAttachHeader(operationID: String) async throws {
        let next = RecordingNext(statuses: [.ok])
        let middleware = makeMiddleware(store: InMemoryTokenStore(tokens: oldTokens))

        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(await next.authorizations == [nil])
    }

    @Test("401 이면 토큰을 갱신해 새 토큰으로 한 번 다시 보낸다")
    func intercept_unauthorized_refreshesAndRetriesOnce() async throws {
        let next = RecordingNext(statuses: [.unauthorized, .ok])
        let middleware = makeMiddleware(store: InMemoryTokenStore(tokens: oldTokens))

        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: protectedOperation, next: next.call
        )

        #expect(response.status == .ok)
        #expect(await next.authorizations == ["Bearer old-access", "Bearer new-access"])
    }

    @Test("다시 보낸 요청도 401 이면 반복하지 않고 그 응답을 돌려준다")
    func intercept_unauthorizedTwice_returnsSecondResponse() async throws {
        let next = RecordingNext(statuses: [.unauthorized, .unauthorized])
        let middleware = makeMiddleware(store: InMemoryTokenStore(tokens: oldTokens))

        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: protectedOperation, next: next.call
        )

        #expect(response.status == .unauthorized)
        #expect(await next.callCount == 2)
    }

    @Test("한 번만 읽을 수 있는 body 는 다시 보내지 않는다")
    func intercept_unauthorizedWithSingleIterationBody_doesNotRetry() async throws {
        let next = RecordingNext(statuses: [.unauthorized, .ok])
        let middleware = makeMiddleware(store: InMemoryTokenStore(tokens: oldTokens))
        let body = HTTPBody([UInt8](), length: .known(0), iterationBehavior: .single)

        let (response, _) = try await middleware.intercept(
            request, body: body, baseURL: baseURL, operationID: protectedOperation, next: next.call
        )

        #expect(response.status == .unauthorized)
        #expect(await next.callCount == 1)
    }

    @Test("공개 operation 의 401 은 토큰 갱신을 일으키지 않는다", arguments: ["login", "refreshToken"])
    func intercept_publicOperationUnauthorized_doesNotRefresh(operationID: String) async throws {
        let next = RecordingNext(statuses: [.unauthorized, .ok])
        let store = InMemoryTokenStore(tokens: oldTokens)
        let middleware = makeMiddleware(store: store)

        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL, operationID: operationID, next: next.call
        )

        #expect(response.status == .unauthorized)
        #expect(await next.callCount == 1)
        #expect(await store.saveCount == 0)
    }

    private func makeMiddleware(store: InMemoryTokenStore) -> AuthMiddleware {
        let newTokens = newTokens
        let refresher = TokenRefresher(store: store, refresh: { _ in newTokens }, onSessionExpired: {})
        return AuthMiddleware(refresher: refresher, publicOperationIDs: PublicOperation.ids)
    }
}

/// 호출 횟수를 센다. `TokenRefresherTests` 의 같은 이름 대역과 같은 역할이다.
private actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

/// `next` 대역. 받은 Authorization 헤더를 기록하고 정해진 상태를 차례로 돌려준다.
private actor RecordingNext {
    private var statuses: [HTTPResponse.Status]
    private(set) var authorizations: [String?] = []

    var callCount: Int {
        authorizations.count
    }

    init(statuses: [HTTPResponse.Status]) {
        self.statuses = statuses
    }

    nonisolated var call: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) {
        { request, _, _ in await self.record(request) }
    }

    private func record(_ request: HTTPRequest) -> (HTTPResponse, HTTPBody?) {
        authorizations.append(request.headerFields[.authorization])
        return (HTTPResponse(status: statuses.removeFirst()), nil)
    }
}
