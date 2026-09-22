//
//  NetworkFailureTests.swift
//  NetworkingTests
//

import Foundation
import HTTPTypes
@testable import Networking
import OpenAPIRuntime
import Testing

@Suite("NetworkFailure 보고 판정과 요약")
struct NetworkFailureTests {
    @Test("취소, 오프라인류, 인증 만료는 보고하지 않는다", arguments: FailureCase.excluded, [false, true])
    private func describe_excludedError_isNotReportable(testCase: FailureCase, wrapped: Bool) {
        let error = wrapped ? FailureCase.wrappedByRuntime(testCase.error) : testCase.error

        #expect(!NetworkFailure.describe(error).isReportable)
    }

    @Test("연결 실패, 타임아웃, 디코딩 실패는 보고한다", arguments: FailureCase.reportable)
    private func describe_reportableError_isReportable(testCase: FailureCase) {
        let error = FailureCase.wrappedByRuntime(testCase.error)

        #expect(NetworkFailure.describe(error).isReportable)
    }

    @Test("URLError 는 타입 이름과 코드를 남긴다")
    func describe_urlError_keepsTypeAndCode() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(URLError(.timedOut)))

        #expect(failure.errorType == "URLError")
        #expect(failure.errorCode == URLError.Code.timedOut.rawValue)
        #expect(failure.summary == "URLError(\(URLError.Code.timedOut.rawValue))")
    }

    @Test("URLError 가 아니면 코드가 없고 요약은 타입 이름이다")
    func describe_decodingError_hasNoCode() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(FailureCase.decodingError))

        #expect(failure.errorCode == nil)
        #expect(failure.summary == "DecodingError")
    }

    @Test("런타임이 감싼 미들웨어 에러는 원래 에러의 타입 이름으로 요약한다")
    func describe_wrappedAuthenticationError_summarizesTypeName() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(AuthenticationError.sessionExpired))

        #expect(failure.summary == "AuthenticationError")
    }

    @Test("감싸지 않은 URLError 도 코드로 요약한다")
    func describe_unwrappedURLError_summarizesCode() {
        let failure = NetworkFailure.describe(URLError(.notConnectedToInternet))

        #expect(failure.summary == "URLError(\(URLError.Code.notConnectedToInternet.rawValue))")
    }

    @Test("연관값이 있는 enum 은 종류에 case 이름을 붙이고 연관값은 담지 않는다")
    func describe_enumWithPayload_appendsCaseName() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(FailureCase.decodingError))

        #expect(failure.errorType == "DecodingError.dataCorrupted")
    }

    @Test("같은 타입의 다른 case 는 종류가 다르다")
    func describe_differentCases_differInErrorType() {
        let keyNotFound = DecodingError.keyNotFound(
            FailureCodingKey.id, .init(codingPath: [], debugDescription: "키 없음")
        )

        let first = NetworkFailure.describe(FailureCase.wrappedByRuntime(FailureCase.decodingError))
        let second = NetworkFailure.describe(FailureCase.wrappedByRuntime(keyNotFound))

        #expect(first.errorType != second.errorType)
    }

    @Test("연관값이 없는 case 는 타입 이름만 남는다")
    func describe_enumWithoutPayload_keepsTypeName() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(AuthenticationError.refreshFailed))

        #expect(failure.errorType == "AuthenticationError")
    }

    @Test("취소는 취소로 표시한다", arguments: [FailureCase.cancellation, .urlError(.cancelled)])
    private func describe_cancellation_isCancellation(testCase: FailureCase) {
        #expect(NetworkFailure.describe(FailureCase.wrappedByRuntime(testCase.error)).isCancellation)
    }

    @Test("오프라인은 보고하지 않지만 취소는 아니다")
    func describe_offline_isNotCancellation() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(URLError(.notConnectedToInternet)))

        #expect(!failure.isCancellation)
    }

    @Test("ClientError 의 operation ID 를 전달한다")
    func describe_clientError_passesOperationID() {
        let failure = NetworkFailure.describe(FailureCase.wrappedByRuntime(URLError(.timedOut)))

        #expect(failure.operationID == FailureCase.operationID)
    }

    @Test("감싸지 않은 에러는 operation ID 가 없다")
    func describe_unwrappedError_hasNoOperationID() {
        #expect(NetworkFailure.describe(URLError(.timedOut)).operationID == nil)
    }

    @Test("응답 헤더의 request ID 를 읽는다")
    func describe_responseWithID_readsRequestID() {
        var headers = HTTPFields()
        headers[NetworkDefaults.requestIDField] = "request-id"
        let error = ClientError(
            operationID: FailureCase.operationID,
            operationInput: FailureCase.operationID,
            response: HTTPResponse(status: .ok, headerFields: headers),
            causeDescription: "Unknown",
            underlyingError: FailureCase.decodingError
        )

        #expect(NetworkFailure.describe(error).requestID == "request-id")
    }

    @Test("응답이 없으면 request ID 가 없다")
    func describe_noResponse_hasNoRequestID() {
        #expect(NetworkFailure.describe(FailureCase.wrappedByRuntime(URLError(.timedOut))).requestID == nil)
    }
}

private enum FailureCodingKey: CodingKey {
    case id
}

/// 판정 테스트의 인자. 에러는 Sendable 이 아니라서 종류만 넘기고 테스트 안에서 만든다.
private enum FailureCase: Sendable, CustomTestStringConvertible {
    case cancellation
    case urlError(URLError.Code)
    case authentication
    case decoding

    static let operationID = "listItems"

    static let excluded: [FailureCase] = [
        .cancellation,
        .urlError(.cancelled),
        .urlError(.notConnectedToInternet),
        .urlError(.networkConnectionLost),
        .urlError(.dataNotAllowed),
        .urlError(.internationalRoamingOff),
        .authentication,
    ]

    static let reportable: [FailureCase] = [
        .urlError(.cannotConnectToHost),
        .urlError(.timedOut),
        .decoding,
    ]

    static var decodingError: DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "응답 디코딩 실패"))
    }

    var error: any Error {
        switch self {
        case .cancellation:
            CancellationError()
        case let .urlError(code):
            URLError(code)
        case .authentication:
            AuthenticationError.sessionExpired
        case .decoding:
            Self.decodingError
        }
    }

    var testDescription: String {
        switch self {
        case .cancellation:
            "CancellationError"
        case let .urlError(code):
            "URLError(\(code.rawValue))"
        case .authentication:
            "AuthenticationError"
        case .decoding:
            "DecodingError"
        }
    }

    /// 런타임이 호출부에 던지는 형태로 감싼다.
    static func wrappedByRuntime(_ error: any Error) -> ClientError {
        ClientError(
            operationID: operationID,
            operationInput: operationID,
            causeDescription: "Transport threw an error.",
            underlyingError: error
        )
    }
}
