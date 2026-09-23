//
//  DefaultFeatureFlagProviderTests.swift
//  FeatureFlagsTests
//

import FeatureFlags
import Testing

@Suite("DefaultFeatureFlagProvider")
struct DefaultFeatureFlagProviderTests {
    @Test("선언된 기본값을 그대로 돌려준다", arguments: [true, false])
    func isEnabled_anyDefault_returnsDefaultValue(defaultValue: Bool) {
        let flag = FeatureFlag(key: "sample_flag", defaultValue: defaultValue)

        #expect(DefaultFeatureFlagProvider().isEnabled(flag) == defaultValue)
    }
}
