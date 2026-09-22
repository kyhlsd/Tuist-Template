//
//  NetworkBreadcrumbAdapter.swift
//  TuistApp
//

import Diagnostics
import Networking

/// 끝난 요청의 요약을 breadcrumb 로 바꿔 남긴다.
///
/// Networking 은 Diagnostics 를 모르므로 조립 지점인 App 이 둘을 잇는다.
struct NetworkBreadcrumbAdapter: NetworkActivityObserving {
    private let recorder: any BreadcrumbRecording

    init(recorder: any BreadcrumbRecording) {
        self.recorder = recorder
    }

    func requestFinished(_ record: NetworkRequestRecord) {
        recorder.record(Self.breadcrumb(from: record))
    }

    /// `"GET /items 200 123ms rid=…"` 형태로 바꾼다. 실패면 status 자리에 실패 요약이 오고 level 이 `.error` 다.
    ///
    /// 취소는 실패가 아니므로 `.info` 로 남긴다. Crashlytics 로그(세션당 64KB)를 에러로 채우지 않는다.
    static func breadcrumb(from record: NetworkRequestRecord) -> Breadcrumb {
        let outcome = record.statusCode.map(String.init) ?? record.failureSummary ?? Format.missing
        let requestID = record.requestID ?? Format.missing
        return Breadcrumb(
            category: Format.category,
            message: "\(record.method) \(record.path) \(outcome) \(record.elapsedMilliseconds)ms rid=\(requestID)",
            level: record.failureSummary == nil || record.isCancellation ? .info : .error
        )
    }
}

private enum Format {
    static let category = "network"
    static let missing = "-"
}
