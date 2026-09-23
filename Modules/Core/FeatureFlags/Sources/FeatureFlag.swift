//
//  FeatureFlag.swift
//  FeatureFlags
//

/// 켜고 끄는 플래그 하나. 원격 값이 없을 때 쓸 기본값을 함께 가진다.
///
/// 피처가 자기 모듈에서 선언한다. 기본값은 이 선언이 유일한 출처다.
///
///     extension FeatureFlag {
///         static let homeBanner = FeatureFlag(key: "home_banner_enabled", defaultValue: false)
///     }
///
/// 같음과 해시는 `key` 만으로 정한다. 원격 설정에서 플래그를 가리키는 것은 키뿐이므로,
/// 기본값이 다르게 적힌 같은 키도 같은 플래그다(예: `StubFeatureFlagProvider(overrides:)` 의 딕셔너리 키).
public struct FeatureFlag: Hashable, Sendable {
    /// 원격 설정의 키.
    public let key: String
    /// 원격 값이 없을 때 돌려줄 값.
    public let defaultValue: Bool

    public init(key: String, defaultValue: Bool) {
        self.key = key
        self.defaultValue = defaultValue
    }

    public static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        lhs.key == rhs.key
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}
