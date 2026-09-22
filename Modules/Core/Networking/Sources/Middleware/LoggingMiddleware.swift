//
//  LoggingMiddleware.swift
//  Networking
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import os

/// 요청마다 method, path, status, 소요 시간을 남긴다.
///
/// 헤더(토큰)와 바디, 쿼리 문자열은 남기지 않는다. 쿼리에 식별자가 들어갈 수 있어서다.
struct LoggingMiddleware: ClientMiddleware {
    private let logger: Logger

    /// - Parameter subsystem: 로그 subsystem. 보통 앱의 번들 ID.
    init(subsystem: String) {
        logger = Logger(subsystem: subsystem, category: NetworkDefaults.logCategory)
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let method = request.method.rawValue
        let path = Self.pathWithoutQuery(request.path)
        let clock = ContinuousClock()
        let start = clock.now

        do {
            let (response, responseBody) = try await next(request, body, baseURL)
            let elapsed = Self.milliseconds(start.duration(to: clock.now))
            logger.debug(
                "\(method, privacy: .public) \(path, privacy: .public) \(response.status.code, privacy: .public) \(elapsed, privacy: .public)ms"
            )
            return (response, responseBody)
        } catch {
            let elapsed = Self.milliseconds(start.duration(to: clock.now))
            let summary = Self.summary(of: error)
            logger.error(
                "\(method, privacy: .public) \(path, privacy: .public) failed \(elapsed, privacy: .public)ms: \(summary, privacy: .public)"
            )
            throw error
        }
    }

    /// 에러를 진단용 한 단어로 줄인다.
    ///
    /// 가장 바깥 미들웨어라 받는 에러는 늘 `ClientError` 이므로 원래 에러를 꺼낸다.
    /// 에러 설명에는 쿼리가 붙은 URL 이나 요청 헤더가 들어갈 수 있으므로 타입과 코드만 남긴다.
    static func summary(of error: any Error) -> String {
        let underlying = (error as? ClientError)?.underlyingError ?? error
        if let urlError = underlying as? URLError {
            return "URLError(\(urlError.code.rawValue))"
        }
        return String(describing: type(of: underlying))
    }

    private static func pathWithoutQuery(_ path: String?) -> String {
        guard let path else {
            return ""
        }
        return path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    }

    private static func milliseconds(_ duration: Duration) -> Int64 {
        let (seconds, attoseconds) = duration.components
        return seconds * Unit.millisecondsPerSecond + attoseconds / Unit.attosecondsPerMillisecond
    }
}

private enum Unit {
    static let millisecondsPerSecond: Int64 = 1000
    static let attosecondsPerMillisecond: Int64 = 1_000_000_000_000_000
}
