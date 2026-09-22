//
//  LoggingMiddlewareTests.swift
//  NetworkingTests
//

import Foundation
@testable import Networking
import OpenAPIRuntime
import Testing

@Suite("LoggingMiddleware 에러 요약")
struct LoggingMiddlewareTests {
    /// 로그 출력은 관찰할 수 없으므로 에러를 로그 문자열로 줄이는 규칙만 고정한다.
    @Test("ClientError 를 풀어 원래 에러의 코드나 타입만 남긴다", arguments: [
        SummaryCase.urlError,
        SummaryCase.authenticationError,
        SummaryCase.unwrappedURLError,
    ])
    private func summary_wrappedError_returnsUnderlyingCodeOrType(testCase: SummaryCase) {
        #expect(LoggingMiddleware.summary(of: testCase.error) == testCase.expected)
    }
}

/// 요약 테스트의 인자. 에러는 Sendable 이 아니라서 종류만 넘기고 테스트 안에서 만든다.
private enum SummaryCase: Sendable, CustomTestStringConvertible {
    /// 런타임이 감싼 transport 에러.
    case urlError
    /// 런타임이 감싼 미들웨어 에러.
    case authenticationError
    /// 감싸지 않은 에러.
    case unwrappedURLError

    var error: any Error {
        switch self {
        case .urlError:
            wrappedByRuntime(URLError(.timedOut))
        case .authenticationError:
            wrappedByRuntime(AuthenticationError.sessionExpired)
        case .unwrappedURLError:
            URLError(.notConnectedToInternet)
        }
    }

    var expected: String {
        switch self {
        case .urlError:
            "URLError(\(URLError.Code.timedOut.rawValue))"
        case .authenticationError:
            "AuthenticationError"
        case .unwrappedURLError:
            "URLError(\(URLError.Code.notConnectedToInternet.rawValue))"
        }
    }

    var testDescription: String {
        switch self {
        case .urlError:
            "ClientError(URLError)"
        case .authenticationError:
            "ClientError(AuthenticationError)"
        case .unwrappedURLError:
            "URLError"
        }
    }

    private func wrappedByRuntime(_ error: any Error) -> ClientError {
        ClientError(
            operationID: "listItems",
            operationInput: "listItems",
            causeDescription: "Transport threw an error.",
            underlyingError: error
        )
    }
}
