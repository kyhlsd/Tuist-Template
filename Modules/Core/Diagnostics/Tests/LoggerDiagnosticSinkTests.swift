//
//  LoggerDiagnosticSinkTests.swift
//  DiagnosticsTests
//

@testable import Diagnostics
import Testing

/// Console 에서 읽는 문구를 고정한다. 로그 출력 자체는 테스트에서 읽을 수 없다.
@Suite("LoggerDiagnosticSink 로그 문구")
struct LoggerDiagnosticSinkTests {
    @Test("breadcrumb 는 category 를 대괄호로 감싸 앞에 붙인다")
    func message_breadcrumb_prefixesCategory() {
        let breadcrumb = Breadcrumb(category: "network", message: "GET /items 200 12ms rid=abc", level: .info)

        #expect(LoggerDiagnosticSink.message(for: breadcrumb) == "[network] GET /items 200 12ms rid=abc")
    }

    @Test("보고는 operation, 타입(코드), 요약, request ID 를 한 줄로 남긴다")
    func message_failureWithAllFields_includesEveryField() {
        let failure = DiagnosticFailure(
            operationID: "listItems",
            errorType: "URLError",
            errorCode: -1004,
            summary: "URLError(-1004)",
            requestID: "abc"
        )

        #expect(LoggerDiagnosticSink.message(for: failure) == "보고: listItems URLError(-1004) URLError(-1004) rid=abc")
    }

    @Test("없는 값은 - 로 채운다")
    func message_failureWithoutOptionalFields_usesPlaceholder() {
        let failure = DiagnosticFailure(
            operationID: nil,
            errorType: "DecodingError.dataCorrupted",
            errorCode: nil,
            summary: "DecodingError",
            requestID: nil
        )

        let expected = "보고: - DecodingError.dataCorrupted(-) DecodingError rid=-"
        #expect(LoggerDiagnosticSink.message(for: failure) == expected)
    }
}
