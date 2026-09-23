//
//  DefaultFeatureFlagProvider.swift
//  FeatureFlags
//

/// 항상 선언된 기본값을 돌려준다.
///
/// 원격 설정을 쓰지 않을 때(Debug, 설정 파일 없음, 데모 앱, 프리뷰) 쓴다.
public struct DefaultFeatureFlagProvider: FeatureFlagProviding {
    public init() {}

    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        flag.defaultValue
    }
}
