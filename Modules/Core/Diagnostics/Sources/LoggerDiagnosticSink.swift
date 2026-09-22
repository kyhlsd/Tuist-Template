//
//  LoggerDiagnosticSink.swift
//  TuistApp
//

import Domain
import os

/// 보고와 breadcrumb 를 `os.Logger` 로만 남긴다.
///
/// Firebase 를 초기화하지 않았을 때(Debug, 설정 파일 없음) 쓴다. 무엇이 보고될지 Console 에서 확인할 수 있다.
/// 모든 필드가 요약값(타입, 코드, 무작위 request ID)이라 공개로 남긴다.
struct LoggerDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func record(_ breadcrumb: Breadcrumb) {
        switch breadcrumb.level {
        case .info:
            logger.info("[\(breadcrumb.category, privacy: .public)] \(breadcrumb.message, privacy: .public)")
        case .error:
            logger.error("[\(breadcrumb.category, privacy: .public)] \(breadcrumb.message, privacy: .public)")
        }
    }

    func send(_ failure: DiagnosticFailure) {
        let operationID = failure.operationID ?? Placeholder.missing
        let errorCode = failure.errorCode.map(String.init) ?? Placeholder.missing
        let requestID = failure.requestID ?? Placeholder.missing
        logger.error(
            "보고: \(operationID, privacy: .public) \(failure.errorType, privacy: .public)(\(errorCode, privacy: .public)) \(failure.summary, privacy: .public) rid=\(requestID, privacy: .public)"
        )
    }
}

private enum Placeholder {
    static let missing = "-"
}
