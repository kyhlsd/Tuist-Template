//
//  CrashlyticsDiagnosticSink.swift
//  TuistApp
//

import Domain
import FirebaseCrashlytics
import Foundation

/// 보고는 Crashlytics 비치명 에러로, breadcrumb 는 Crashlytics 로그로 보낸다.
///
/// 로그는 비치명 에러와 크래시 리포트 양쪽에 붙는다. 비치명 에러는 다음 실행 때 전송된다.
/// `Crashlytics` 인스턴스는 Sendable 이 아니므로 저장하지 않고 호출할 때마다 받는다.
/// Firebase 를 초기화한 뒤에만 쓴다(`FirebaseBootstrap`).
struct CrashlyticsDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording {
    func record(_ breadcrumb: Breadcrumb) {
        Crashlytics.crashlytics().log("[\(breadcrumb.category)] \(breadcrumb.message)")
    }

    func send(_ failure: DiagnosticFailure) {
        // 요약값은 NSError 의 userInfo 에 담겨 함께 전송된다. 따로 더할 값이 없다.
        Crashlytics.crashlytics().record(error: Self.nsError(for: failure), userInfo: nil)
    }

    /// Crashlytics 가 domain 과 code 로 이슈를 묶으므로 operation 과 에러 타입을 domain 에 담는다.
    ///
    /// 실행마다 바뀌는 값(Swift `hashValue` 등)은 쓰지 않는다. 같은 에러가 다른 이슈로 갈라진다.
    static func nsError(for failure: DiagnosticFailure) -> NSError {
        let operationID = failure.operationID ?? ErrorFormat.unknownOperation
        var userInfo: [String: Any] = [ErrorFormat.summaryKey: failure.summary]
        if let requestID = failure.requestID {
            userInfo[ErrorFormat.requestIDKey] = requestID
        }
        return NSError(
            domain: "\(ErrorFormat.domainPrefix).\(operationID).\(failure.errorType)",
            code: failure.errorCode ?? ErrorFormat.missingCode,
            userInfo: userInfo
        )
    }
}

private enum ErrorFormat {
    static let domainPrefix = "network"
    static let unknownOperation = "unknown"
    static let missingCode = 0
    static let summaryKey = "summary"
    static let requestIDKey = "requestID"
}
