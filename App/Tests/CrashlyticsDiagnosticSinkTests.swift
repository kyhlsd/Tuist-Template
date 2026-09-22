//
//  CrashlyticsDiagnosticSinkTests.swift
//  TuistAppTests
//

import Domain
import Foundation
import Testing
@testable import TuistApp

/// NSError 매핑만 검증한다. Crashlytics 호출은 Firebase 를 초기화해야 해서 테스트하지 않는다(Debug 는 초기화하지 않는다).
@Suite("CrashlyticsDiagnosticSink NSError 매핑")
struct CrashlyticsDiagnosticSinkTests {
    @Test("domain 에 operation 과 에러 타입을 담는다")
    func nsError_domain_includesOperationAndType() {
        let error = CrashlyticsDiagnosticSink.nsError(for: failure(errorCode: -1001))

        #expect(error.domain == "network.listItems.URLError")
    }

    @Test("code 는 에러 코드다")
    func nsError_code_isErrorCode() {
        #expect(CrashlyticsDiagnosticSink.nsError(for: failure(errorCode: -1001)).code == -1001)
    }

    @Test("에러 코드가 없으면 code 는 0 이다")
    func nsError_noErrorCode_isZero() {
        #expect(CrashlyticsDiagnosticSink.nsError(for: failure(errorCode: nil)).code == 0)
    }

    @Test("userInfo 에 요약과 request ID 를 담는다")
    func nsError_userInfo_includesSummaryAndRequestID() {
        let error = CrashlyticsDiagnosticSink.nsError(for: failure(requestID: "request-id"))

        #expect(error.userInfo["summary"] as? String == "URLError(-1001)")
        #expect(error.userInfo["requestID"] as? String == "request-id")
    }

    @Test("request ID 가 없으면 userInfo 에 키가 없다")
    func nsError_noRequestID_omitsKey() {
        let error = CrashlyticsDiagnosticSink.nsError(for: failure(requestID: nil))

        #expect(error.userInfo["requestID"] == nil)
    }

    private func failure(errorCode: Int? = -1001, requestID: String? = nil) -> DiagnosticFailure {
        DiagnosticFailure(
            operationID: "listItems",
            errorType: "URLError",
            errorCode: errorCode,
            summary: "URLError(-1001)",
            requestID: requestID
        )
    }
}
