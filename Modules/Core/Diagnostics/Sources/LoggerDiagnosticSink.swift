//
//  LoggerDiagnosticSink.swift
//  Diagnostics
//

import os

/// 보고와 breadcrumb 를 `os.Logger` 로만 남긴다.
///
/// 전송 수단을 쓰지 않을 때(Debug, 설정 파일 없음, 데모 앱) 쓴다. 무엇이 보고될지 Console 에서 확인할 수 있다.
/// 모든 필드가 요약값(타입, 코드, 무작위 request ID)이라 공개로 남긴다.
public struct LoggerDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func record(_ breadcrumb: Breadcrumb) {
        let message = Self.message(for: breadcrumb)
        switch breadcrumb.level {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    public func send(_ failure: DiagnosticFailure) {
        logger.error("\(Self.message(for: failure), privacy: .public)")
    }

    /// `"[network] GET /items 200 123ms rid=…"` 형태. 로그 출력은 테스트에서 읽을 수 없으므로 문구만 분리해 테스트한다.
    static func message(for breadcrumb: Breadcrumb) -> String {
        "[\(breadcrumb.category)] \(breadcrumb.message)"
    }

    /// `"보고: listItems URLError(-1004) URLError(-1004) rid=…"` 형태. 없는 값은 `-` 로 채운다.
    static func message(for failure: DiagnosticFailure) -> String {
        let operationID = failure.operationID ?? Placeholder.missing
        let errorCode = failure.errorCode.map(String.init) ?? Placeholder.missing
        let requestID = failure.requestID ?? Placeholder.missing
        return "보고: \(operationID) \(failure.errorType)(\(errorCode)) \(failure.summary) rid=\(requestID)"
    }
}

private enum Placeholder {
    static let missing = "-"
}
