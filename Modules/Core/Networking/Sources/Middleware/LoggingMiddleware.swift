//
//  LoggingMiddleware.swift
//  Networking
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import os

/// 요청마다 method, path, status, 소요 시간, request ID 를 남기고 옵저버에 알린다.
///
/// 헤더(토큰)와 바디, 쿼리 문자열은 남기지 않는다. 쿼리에 식별자가 들어갈 수 있어서다.
struct LoggingMiddleware: ClientMiddleware {
    /// 요청에 request ID 가 없을 때(RequestIDMiddleware 가 바깥에 없을 때) 남기는 값.
    static let missingRequestID = "-"

    private let logger: Logger
    private let observer: any NetworkActivityObserving

    /// - Parameters:
    ///   - subsystem: 로그 subsystem. 보통 앱의 번들 ID.
    ///   - observer: 요청이 끝날 때마다 로그를 남긴 뒤 요약을 받는다.
    init(subsystem: String, observer: any NetworkActivityObserving) {
        logger = Logger(subsystem: subsystem, category: NetworkDefaults.logCategory)
        self.observer = observer
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
        let requestID = request.headerFields[NetworkDefaults.requestIDField]
        // 무작위 UUID 라 식별 정보가 아니다. 서버 로그와 잇기 위해 공개로 남긴다.
        let loggedRequestID = requestID ?? Self.missingRequestID
        let clock = ContinuousClock()
        let start = clock.now

        do {
            let (response, responseBody) = try await next(request, body, baseURL)
            let elapsed = Self.milliseconds(start.duration(to: clock.now))
            logger.debug(
                "\(method, privacy: .public) \(path, privacy: .public) \(response.status.code, privacy: .public) \(elapsed, privacy: .public)ms rid=\(loggedRequestID, privacy: .public)"
            )
            observer.requestFinished(NetworkRequestRecord(
                method: method,
                path: path,
                statusCode: response.status.code,
                failureSummary: nil,
                isCancellation: false,
                elapsedMilliseconds: elapsed,
                requestID: requestID
            ))
            return (response, responseBody)
        } catch {
            let elapsed = Self.milliseconds(start.duration(to: clock.now))
            let failure = NetworkFailure.describe(error)
            let summary = failure.summary
            if failure.isCancellation {
                // 취소는 실패가 아니다. error 레벨로 남기면 Console 의 에러 필터를 차지한다.
                logger.info(
                    "\(method, privacy: .public) \(path, privacy: .public) cancelled \(elapsed, privacy: .public)ms: \(summary, privacy: .public) rid=\(loggedRequestID, privacy: .public)"
                )
            } else {
                logger.error(
                    "\(method, privacy: .public) \(path, privacy: .public) failed \(elapsed, privacy: .public)ms: \(summary, privacy: .public) rid=\(loggedRequestID, privacy: .public)"
                )
            }
            observer.requestFinished(NetworkRequestRecord(
                method: method,
                path: path,
                statusCode: nil,
                failureSummary: summary,
                isCancellation: failure.isCancellation,
                elapsedMilliseconds: elapsed,
                requestID: requestID
            ))
            throw error
        }
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
