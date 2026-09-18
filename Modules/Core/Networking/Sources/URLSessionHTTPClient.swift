//
//  URLSessionHTTPClient.swift
//  Networking
//

import Foundation

/// `URLSession` 기반 `HTTPClient`.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws(NetworkError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw .transport(error.code)
        } catch {
            // URLSession 은 URLError 만 던진다. 그 밖의 경우(취소 등)도 전송 실패로 본다.
            throw .transport(.unknown)
        }

        try Self.validate(response)
        return data
    }

    /// 응답이 2xx HTTP 응답인지 확인한다.
    static func validate(_ response: URLResponse) throws(NetworkError) {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }
        guard Self.acceptableStatusCodes.contains(httpResponse.statusCode) else {
            throw .unacceptableStatus(httpResponse.statusCode)
        }
    }

    private static let acceptableStatusCodes = 200 ..< 300
}
