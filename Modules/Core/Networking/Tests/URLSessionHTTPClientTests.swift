//
//  URLSessionHTTPClientTests.swift
//  NetworkingTests
//

import Foundation
@testable import Networking
import Testing

@Suite("URLSessionHTTPClient 응답 검증")
struct URLSessionHTTPClientTests {
    private let url = URL(filePath: "/items")

    @Test("2xx 응답은 통과한다")
    func validate_successStatus_doesNotThrow() throws {
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)
        )

        #expect(throws: Never.self) {
            try URLSessionHTTPClient.validate(response)
        }
    }

    @Test("2xx 가 아니면 상태 코드를 담아 실패한다")
    func validate_errorStatus_throwsUnacceptableStatus() throws {
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        )

        #expect(throws: NetworkError.unacceptableStatus(404)) {
            try URLSessionHTTPClient.validate(response)
        }
    }

    @Test("HTTP 응답이 아니면 실패한다")
    func validate_nonHTTPResponse_throwsInvalidResponse() {
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

        #expect(throws: NetworkError.invalidResponse) {
            try URLSessionHTTPClient.validate(response)
        }
    }
}
