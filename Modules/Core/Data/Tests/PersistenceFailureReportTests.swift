//
//  PersistenceFailureReportTests.swift
//  DataTests
//

import Data
import Diagnostics
import DiagnosticsTesting
import Persistence
import Testing

@Suite("reportPersistenceFailure")
struct PersistenceFailureReportTests {
    @Test("서로 다른 case 는 fingerprint 가 달라 서로의 보고를 억제하지 않는다")
    func reportPersistenceFailure_differentCases_haveDifferentFingerprints() {
        let reporter = SpyDiagnosticReporter()

        reporter.reportPersistenceFailure(.decodingFailed)
        reporter.reportPersistenceFailure(.operationFailed)

        #expect(reporter.reported.map(\.errorType) == [
            "PersistenceError.decodingFailed",
            "PersistenceError.operationFailed",
        ])
        #expect(Set(reporter.reported.map(\.fingerprint)).count == 2)
    }
}
