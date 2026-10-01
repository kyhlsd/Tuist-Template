//
//  DiagnosticReporting+PersistenceError.swift
//  Data
//

import Diagnostics
import Persistence

public extension DiagnosticReporting {
    /// 기기 안 저장소의 실패를 보고한다. 서버를 거치지 않으므로 operation ID 와 request ID 는 없다.
    ///
    /// Repository 의 Persistence 호출 `catch` 에서 부른다. 결과를 기다리지 않는다.
    /// App 도 디스크 저장소를 열지 못했을 때 같은 형식으로 보고하려고 쓴다.
    func reportPersistenceFailure(_ error: PersistenceError) {
        // 연관값이 없는 case 라 case 이름만 나온다.
        let caseName = String(describing: error)
        report(DiagnosticFailure(
            operationID: nil,
            // case 마다 fingerprint 가 달라야 한 원인이 다른 원인의 보고를 억제하지 않는다.
            // `NetworkFailure` 의 `타입.case` 형식을 따른다.
            errorType: "\(PersistenceReport.errorType).\(caseName)",
            errorCode: nil,
            summary: caseName,
            requestID: nil
        ))
    }
}

private enum PersistenceReport {
    static let errorType = "PersistenceError"
}
