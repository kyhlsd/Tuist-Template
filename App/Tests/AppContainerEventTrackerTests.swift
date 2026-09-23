//
//  AppContainerEventTrackerTests.swift
//  TuistAppTests
//

import os
import Testing
import Tracking
@testable import TuistApp

/// Firebase 초기화 결정이 어떤 기록기로 이어지는지 고정한다.
///
/// `FirebaseEventTracker` 는 저장 프로퍼티가 없어 만들기만 해서는 Firebase 를 부르지 않는다. Debug 에서도 안전하다.
@MainActor
@Suite("AppContainer 이벤트 기록기 선택")
struct AppContainerEventTrackerTests {
    @Test("Firebase 를 초기화했으면 Analytics 기록기를 쓴다")
    func makeEventTracker_configure_usesFirebase() {
        let tracker = AppContainer.makeEventTracker(firebaseDecision: .configure, logger: Logger(.disabled))

        #expect(tracker is FirebaseEventTracker)
    }

    @Test("Firebase 를 건너뛰었으면 로그 기록기를 쓴다", arguments: [
        FirebaseBootstrap.Decision.skipDebug,
        FirebaseBootstrap.Decision.skipMissingConfigFile,
    ])
    func makeEventTracker_skipped_usesLogger(decision: FirebaseBootstrap.Decision) {
        let tracker = AppContainer.makeEventTracker(firebaseDecision: decision, logger: Logger(.disabled))

        #expect(tracker is LoggerEventTracker)
    }
}
