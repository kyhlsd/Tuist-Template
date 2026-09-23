//
//  FeatureFlagProviding.swift
//  FeatureFlags
//

/// 플래그 값을 읽는 곳.
///
/// 값 출처(Firebase Remote Config 등)를 바꾸는 경계다. 피처는 이 프로토콜을 생성자로 받고 출처를 모른다.
public protocol FeatureFlagProviding: Sendable {
    /// 동기로 읽는다. 원격 값이 없으면 `flag.defaultValue` 를 돌려준다.
    ///
    /// 값은 앱 실행 중에 한 번 바뀔 수 있다(README 참고). 이미 읽은 값은 다시 알려주지 않는다.
    func isEnabled(_ flag: FeatureFlag) -> Bool
}
