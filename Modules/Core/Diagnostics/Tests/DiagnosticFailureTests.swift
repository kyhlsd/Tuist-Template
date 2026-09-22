//
//  DiagnosticFailureTests.swift
//  DiagnosticsTests
//

import Diagnostics
import Testing

@Suite("DiagnosticFailure fingerprint")
struct DiagnosticFailureTests {
    @Test("summary 와 request ID 가 달라도 fingerprint 는 같다")
    func fingerprint_differentSummaryAndRequestID_isEqual() {
        let first = failure(summary: "URLError(-1001)", requestID: "a")
        let second = failure(summary: "다른 요약", requestID: nil)

        #expect(first.fingerprint == second.fingerprint)
    }

    @Test("operation 이 다르면 fingerprint 가 다르다")
    func fingerprint_differentOperation_differs() {
        #expect(failure(operationID: "listItems").fingerprint != failure(operationID: "login").fingerprint)
    }

    @Test("에러 타입이 다르면 fingerprint 가 다르다")
    func fingerprint_differentErrorType_differs() {
        #expect(failure(errorType: "URLError").fingerprint != failure(errorType: "DecodingError").fingerprint)
    }

    @Test("에러 코드가 다르면 fingerprint 가 다르다")
    func fingerprint_differentErrorCode_differs() {
        #expect(failure(errorCode: -1001).fingerprint != failure(errorCode: -1004).fingerprint)
    }

    private func failure(
        operationID: String? = "listItems",
        errorType: String = "URLError",
        errorCode: Int? = -1001,
        summary: String = "URLError(-1001)",
        requestID: String? = nil
    ) -> DiagnosticFailure {
        DiagnosticFailure(
            operationID: operationID,
            errorType: errorType,
            errorCode: errorCode,
            summary: summary,
            requestID: requestID
        )
    }
}
