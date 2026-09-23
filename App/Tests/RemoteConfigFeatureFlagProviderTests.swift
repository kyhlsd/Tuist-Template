//
//  RemoteConfigFeatureFlagProviderTests.swift
//  TuistAppTests
//

import FirebaseRemoteConfig
import Testing
@testable import TuistApp

/// 값 출처에 따른 판정만 검증한다. Remote Config 호출은 Firebase 를 초기화해야 해서 테스트하지 않는다.
@Suite("RemoteConfigFeatureFlagProvider 값 판정")
struct RemoteConfigFeatureFlagProviderTests {
    @Test("값이 없으면(.static) 기본값을 쓴다", arguments: [true, false])
    func resolve_static_usesDefault(defaultValue: Bool) {
        let resolved = RemoteConfigFeatureFlagProvider.resolve(
            source: .static,
            remoteValue: !defaultValue,
            defaultValue: defaultValue
        )

        #expect(resolved == defaultValue)
    }

    @Test("원격 값(.remote)이 있으면 원격 값을 쓴다", arguments: [true, false])
    func resolve_remote_usesRemoteValue(remoteValue: Bool) {
        let resolved = RemoteConfigFeatureFlagProvider.resolve(
            source: .remote,
            remoteValue: remoteValue,
            defaultValue: !remoteValue
        )

        #expect(resolved == remoteValue)
    }

    /// `setDefaults` 를 쓰지 않으므로 나오지 않지만, 나온다면 Remote Config 의 값을 따른다는 규칙을 고정한다.
    @Test("SDK 기본값(.default)이면 그 값을 쓴다", arguments: [true, false])
    func resolve_sdkDefault_usesRemoteValue(remoteValue: Bool) {
        let resolved = RemoteConfigFeatureFlagProvider.resolve(
            source: .default,
            remoteValue: remoteValue,
            defaultValue: !remoteValue
        )

        #expect(resolved == remoteValue)
    }
}
