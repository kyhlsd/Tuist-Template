//
//  APIClientFactoryTests.swift
//  NetworkingTests
//

import Foundation
@testable import Networking
import OpenAPIRuntime
import Testing

@Suite("APIClientFactory refresh 응답 매핑")
struct APIClientFactoryTests {
    @Test("200 응답은 토큰으로 바뀐다")
    func refreshTokens_ok_returnsTokens() async throws {
        let pair = Components.Schemas.TokenPair(accessToken: "new-access", refreshToken: "new-refresh")
        let client = StubRefreshAPI(output: .ok(.init(body: .json(pair))))

        let tokens = try await APIClientFactory.refreshTokens(using: client, refreshToken: "old-refresh")

        #expect(tokens == AuthTokens(accessToken: "new-access", refreshToken: "new-refresh"))
    }

    @Test("거절과 명세 밖 응답을 구분한다", arguments: [
        RejectedResponse.badRequest,
        RejectedResponse.unauthorized,
        RejectedResponse.undocumented,
    ])
    private func refreshTokens_nonOK_throwsMatchingError(response: RejectedResponse) async {
        let client = StubRefreshAPI(output: response.output)

        await #expect(throws: response.expectedError) {
            try await APIClientFactory.refreshTokens(using: client, refreshToken: "old-refresh")
        }
    }
}

/// 매핑 테스트의 인자. 기대 에러가 로그아웃(`sessionExpired`)과 토큰 유지(`refreshFailed`)를 가른다.
private enum RejectedResponse: Sendable, CustomTestStringConvertible {
    case badRequest
    case unauthorized
    case undocumented

    var output: Operations.RefreshToken.Output {
        let error = Components.Schemas.ErrorResponse(code: "rejected", message: "")
        switch self {
        case .badRequest:
            return .badRequest(.init(body: .json(error)))
        case .unauthorized:
            return .unauthorized(.init(body: .json(error)))
        case .undocumented:
            return .undocumented(statusCode: 500, UndocumentedPayload())
        }
    }

    var expectedError: AuthenticationError {
        switch self {
        case .badRequest, .unauthorized:
            .sessionExpired
        case .undocumented:
            .refreshFailed
        }
    }

    var testDescription: String {
        switch self {
        case .badRequest:
            "400"
        case .unauthorized:
            "401"
        case .undocumented:
            "명세에 없는 500"
        }
    }
}

/// refreshToken 만 응답하는 `APIProtocol`. 나머지 operation 은 기록 후 실패한다.
private struct StubRefreshAPI: APIProtocol {
    let output: Operations.RefreshToken.Output

    func listItems(_: Operations.ListItems.Input) async throws -> Operations.ListItems.Output {
        Issue.record("이 테스트는 listItems 를 호출하지 않아야 한다")
        throw UnexpectedCall()
    }

    func login(_: Operations.Login.Input) async throws -> Operations.Login.Output {
        Issue.record("이 테스트는 login 을 호출하지 않아야 한다")
        throw UnexpectedCall()
    }

    func refreshToken(_: Operations.RefreshToken.Input) async throws -> Operations.RefreshToken.Output {
        output
    }
}

private struct UnexpectedCall: Error {}
