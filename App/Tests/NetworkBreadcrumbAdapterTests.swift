//
//  NetworkBreadcrumbAdapterTests.swift
//  TuistAppTests
//

import Diagnostics
import Networking
import Testing
@testable import TuistApp

@Suite("NetworkBreadcrumbAdapter 변환")
struct NetworkBreadcrumbAdapterTests {
    @Test("성공 요약은 status 가 담긴 info breadcrumb 가 된다")
    func breadcrumb_success_isInfoWithStatus() {
        let record = NetworkRequestRecord(
            method: "GET", path: "/items", statusCode: 200, failureSummary: nil, isCancellation: false,
            elapsedMilliseconds: 123, requestID: "request-id"
        )

        let breadcrumb = NetworkBreadcrumbAdapter.breadcrumb(from: record)

        #expect(breadcrumb == Breadcrumb(
            category: "network", message: "GET /items 200 123ms rid=request-id", level: .info
        ))
    }

    @Test("실패 요약은 실패 요약이 담긴 error breadcrumb 가 된다")
    func breadcrumb_failure_isErrorWithSummary() {
        let record = NetworkRequestRecord(
            method: "GET", path: "/items", statusCode: nil, failureSummary: "URLError(-1001)", isCancellation: false,
            elapsedMilliseconds: 15000, requestID: "request-id"
        )

        let breadcrumb = NetworkBreadcrumbAdapter.breadcrumb(from: record)

        #expect(breadcrumb == Breadcrumb(
            category: "network", message: "GET /items URLError(-1001) 15000ms rid=request-id", level: .error
        ))
    }

    @Test("취소는 info breadcrumb 가 된다")
    func breadcrumb_cancellation_isInfo() {
        let record = NetworkRequestRecord(
            method: "GET", path: "/items", statusCode: nil, failureSummary: "URLError(-999)", isCancellation: true,
            elapsedMilliseconds: 10, requestID: "request-id"
        )

        #expect(NetworkBreadcrumbAdapter.breadcrumb(from: record).level == .info)
    }

    @Test("request ID 가 없으면 rid=- 를 남긴다")
    func breadcrumb_noRequestID_usesPlaceholder() {
        let record = NetworkRequestRecord(
            method: "GET", path: "/items", statusCode: 200, failureSummary: nil, isCancellation: false,
            elapsedMilliseconds: 5, requestID: nil
        )

        #expect(NetworkBreadcrumbAdapter.breadcrumb(from: record).message == "GET /items 200 5ms rid=-")
    }
}
