//
//  DiagnosticReporting+NetworkFailure.swift
//  Data
//

import Diagnostics
import Networking

extension DiagnosticReporting {
    /// 생성 클라이언트가 던진 에러를 `NetworkFailure` 로 판정해, 서버가 볼 수 없는 에러만 보고한다.
    ///
    /// Repository 의 생성 클라이언트 호출 `catch` 에서 부른다. 결과를 기다리지 않는다.
    func reportNetworkFailure(_ error: any Error) {
        let failure = NetworkFailure.describe(error)
        guard failure.isReportable else {
            return
        }
        report(DiagnosticFailure(
            operationID: failure.operationID,
            errorType: failure.errorType,
            errorCode: failure.errorCode,
            summary: failure.summary,
            requestID: failure.requestID
        ))
    }
}
