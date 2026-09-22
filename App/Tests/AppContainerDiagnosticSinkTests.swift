//
//  AppContainerDiagnosticSinkTests.swift
//  TuistAppTests
//

import Diagnostics
import os
import Testing
@testable import TuistApp

/// Firebase 초기화 결정이 어떤 싱크로 이어지는지 고정한다.
///
/// `CrashlyticsDiagnosticSink` 는 저장 프로퍼티가 없어 만들기만 해서는 Firebase 를 부르지 않는다. Debug 에서도 안전하다.
@MainActor
@Suite("AppContainer 진단 싱크 선택")
struct AppContainerDiagnosticSinkTests {
    @Test("Firebase 를 초기화했으면 Crashlytics 싱크를 쓴다")
    func makeDiagnosticSink_configure_usesCrashlytics() {
        let sink = AppContainer.makeDiagnosticSink(firebaseDecision: .configure, logger: Logger(.disabled))

        #expect(sink is CrashlyticsDiagnosticSink)
    }

    @Test("Firebase 를 건너뛰었으면 로그 싱크를 쓴다", arguments: [
        FirebaseBootstrap.Decision.skipDebug,
        FirebaseBootstrap.Decision.skipMissingConfigFile,
    ])
    func makeDiagnosticSink_skipped_usesLogger(decision: FirebaseBootstrap.Decision) {
        let sink = AppContainer.makeDiagnosticSink(firebaseDecision: decision, logger: Logger(.disabled))

        #expect(sink is LoggerDiagnosticSink)
    }
}
