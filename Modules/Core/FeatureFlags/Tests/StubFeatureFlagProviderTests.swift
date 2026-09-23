//
//  StubFeatureFlagProviderTests.swift
//  FeatureFlagsTests
//

import FeatureFlags
import FeatureFlagsTesting
import Testing

/// 플래그를 키로 찾는지 고정한다. `FeatureFlag` 의 같음이 `key` 만 보는지에 달려 있다.
@Suite("StubFeatureFlagProvider")
struct StubFeatureFlagProviderTests {
    @Test("지정한 플래그는 지정한 값을 돌려준다")
    func isEnabled_overridden_returnsOverride() {
        let flag = FeatureFlag(key: Key.sample, defaultValue: false)

        #expect(StubFeatureFlagProvider(overrides: [flag: true]).isEnabled(flag))
    }

    @Test("기본값이 다르게 적혀도 키가 같으면 지정한 값을 돌려준다")
    func isEnabled_sameKeyDifferentDefault_returnsOverride() {
        let declared = FeatureFlag(key: Key.sample, defaultValue: false)
        let overrideKey = FeatureFlag(key: Key.sample, defaultValue: true)

        #expect(StubFeatureFlagProvider(overrides: [overrideKey: true]).isEnabled(declared))
    }

    @Test("지정하지 않은 플래그는 기본값을 돌려준다", arguments: [true, false])
    func isEnabled_notOverridden_returnsDefault(defaultValue: Bool) {
        let flag = FeatureFlag(key: Key.sample, defaultValue: defaultValue)
        let other = FeatureFlag(key: Key.other, defaultValue: !defaultValue)

        #expect(StubFeatureFlagProvider(overrides: [other: !defaultValue]).isEnabled(flag) == defaultValue)
    }
}

private enum Key {
    static let sample = "sample_flag"
    static let other = "other_flag"
}
