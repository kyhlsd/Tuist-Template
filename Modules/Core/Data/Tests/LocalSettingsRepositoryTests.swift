//
//  LocalSettingsRepositoryTests.swift
//  DataTests
//

import Data
import Diagnostics
import DiagnosticsTesting
import Foundation
import PersistenceTesting
import Testing

@Suite("LocalSettingsRepository")
struct LocalSettingsRepositoryTests {
    private let reporter = SpyDiagnosticReporter()

    @Test("저장된 값이 없으면 온보딩을 끝내지 않은 것이다")
    func hasCompletedOnboarding_initially_returnsFalse() {
        let repository = LocalSettingsRepository(store: InMemoryKeyValueStore(), reporter: reporter)

        #expect(repository.hasCompletedOnboarding() == false)
    }

    @Test("true 로 저장하면 온보딩을 끝낸 것이다")
    func hasCompletedOnboarding_afterSettingTrue_returnsTrue() {
        let repository = LocalSettingsRepository(store: InMemoryKeyValueStore(), reporter: reporter)

        repository.setHasCompletedOnboarding(true)

        #expect(repository.hasCompletedOnboarding() == true)
    }

    @Test("저장된 값이 깨져 있으면 false 를 돌려주고 한 번 보고한다")
    func hasCompletedOnboarding_whenStoredValueIsCorrupted_returnsFalseAndReportsOnce() {
        let store = InMemoryKeyValueStore(values: ["hasCompletedOnboarding": Data("not json".utf8)])
        let repository = LocalSettingsRepository(store: store, reporter: reporter)

        let completed = repository.hasCompletedOnboarding()

        #expect(completed == false)
        #expect(reporter.reported == [DiagnosticFailure(
            operationID: nil,
            errorType: "PersistenceError.decodingFailed",
            errorCode: nil,
            summary: "decodingFailed",
            requestID: nil
        )])
    }
}
