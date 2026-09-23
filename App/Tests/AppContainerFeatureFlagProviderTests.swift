//
//  AppContainerFeatureFlagProviderTests.swift
//  TuistAppTests
//

import FeatureFlags
import Testing
@testable import TuistApp

/// Firebase 초기화 결정이 어떤 플래그 제공자와 원격 값 받기로 이어지는지 고정한다.
///
/// `RemoteConfigFeatureFlagProvider` 는 저장 프로퍼티가 없어 만들기만 해서는 Firebase 를 부르지 않는다. Debug 에서도 안전하다.
/// 받기 시작은 클로저로 대신해 Firebase 를 부르지 않는다.
@MainActor
@Suite("AppContainer 플래그 제공자 선택")
struct AppContainerFeatureFlagProviderTests {
    @Test("Firebase 를 초기화했으면 Remote Config 제공자를 쓴다")
    func makeFeatureFlagProvider_configure_usesRemoteConfig() {
        let provider = AppContainer.makeFeatureFlagProvider(firebaseDecision: .configure) {}

        #expect(provider is RemoteConfigFeatureFlagProvider)
    }

    @Test("Firebase 를 초기화했으면 원격 값을 한 번 받기 시작한다")
    func makeFeatureFlagProvider_configure_startsFetchOnce() {
        var fetchCount = 0

        _ = AppContainer.makeFeatureFlagProvider(firebaseDecision: .configure) { fetchCount += 1 }

        #expect(fetchCount == 1)
    }

    @Test("Firebase 를 건너뛰었으면 기본값 제공자를 쓴다", arguments: [
        FirebaseBootstrap.Decision.skipDebug,
        FirebaseBootstrap.Decision.skipMissingConfigFile,
    ])
    func makeFeatureFlagProvider_skipped_usesDefault(decision: FirebaseBootstrap.Decision) {
        let provider = AppContainer.makeFeatureFlagProvider(firebaseDecision: decision) {}

        #expect(provider is DefaultFeatureFlagProvider)
    }

    @Test("Firebase 를 건너뛰었으면 원격 값을 받지 않는다", arguments: [
        FirebaseBootstrap.Decision.skipDebug,
        FirebaseBootstrap.Decision.skipMissingConfigFile,
    ])
    func makeFeatureFlagProvider_skipped_doesNotStartFetch(decision: FirebaseBootstrap.Decision) {
        var fetchCount = 0

        _ = AppContainer.makeFeatureFlagProvider(firebaseDecision: decision) { fetchCount += 1 }

        #expect(fetchCount == 0)
    }
}
