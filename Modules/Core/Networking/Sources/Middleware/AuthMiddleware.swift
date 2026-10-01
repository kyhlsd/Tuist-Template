//
//  AuthMiddleware.swift
//  Networking
//

import Auth
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// 요청에 access token 을 붙이고, 401 이면 토큰을 갱신해 한 번만 다시 보낸다.
///
/// 공개 operation 은 건드리지 않는다. 다시 보낸 요청도 401 이면 그 응답을 그대로 돌려준다.
struct AuthMiddleware: ClientMiddleware {
    private let tokenProvider: any AccessTokenProviding
    private let publicOperationIDs: Set<String>

    init(tokenProvider: any AccessTokenProviding, publicOperationIDs: Set<String>) {
        self.tokenProvider = tokenProvider
        self.publicOperationIDs = publicOperationIDs
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if publicOperationIDs.contains(operationID) {
            return try await next(request, body, baseURL)
        }

        let token = try await tokenProvider.currentAccessToken()
        let (response, responseBody) = try await next(Self.authorized(request, token: token.value), body, baseURL)

        // 한 번만 읽을 수 있는 body 는 다시 보낼 수 없으므로 원래 응답을 돌려준다.
        let isReplayable = body.map { $0.iterationBehavior == .multiple } ?? true
        guard response.status == .unauthorized, isReplayable else {
            return (response, responseBody)
        }

        // 읽은 값을 그대로 넘긴다. 그사이 세션이 바뀌었으면 갱신하지 않고 `sessionExpired` 로 끝난다.
        let refreshedToken = try await tokenProvider.refreshedAccessToken(rejected: token)
        return try await next(Self.authorized(request, token: refreshedToken), body, baseURL)
    }

    private static func authorized(_ request: HTTPRequest, token: String?) -> HTTPRequest {
        guard let token else {
            return request
        }
        var request = request
        request.headerFields[.authorization] = "\(Scheme.bearer)\(token)"
        return request
    }
}

private enum Scheme {
    static let bearer = "Bearer "
}
