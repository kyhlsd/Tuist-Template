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
        report(DiagnosticFailure(
            operationID: nil,
            errorType: PersistenceReport.errorType,
            errorCode: nil,
            // 연관값이 없는 case 라 case 이름만 나온다.
            summary: String(describing: error),
            requestID: nil
        ))
    }
}

private enum PersistenceReport {
    static let errorType = "PersistenceError"
}
