//
//  StubFeatureFlagProvider.swift
//  FeatureFlagsTesting
//

import FeatureFlags

/// 지정한 플래그만 원하는 값으로 돌려주고, 나머지는 기본값을 돌려준다.
///
/// 값이 바뀌지 않으므로 잠금 없이 `Sendable` 이다.
public struct StubFeatureFlagProvider: FeatureFlagProviding {
    private let overrides: [FeatureFlag: Bool]

    public init(overrides: [FeatureFlag: Bool] = [:]) {
        self.overrides = overrides
    }

    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        overrides[flag] ?? flag.defaultValue
    }
}
