//
//  StubSettingsRepository.swift
//  DomainTesting
//

import Domain

/// 정해진 값을 돌려주는 `SettingsRepository`.
///
/// 테스트와 데모 앱이 함께 쓴다. 쓰기는 기록하지 않으므로 읽기 값은 바뀌지 않는다.
public struct StubSettingsRepository: SettingsRepository {
    private let completedOnboarding: Bool

    public init(hasCompletedOnboarding: Bool = false) {
        completedOnboarding = hasCompletedOnboarding
    }

    public func hasCompletedOnboarding() -> Bool {
        completedOnboarding
    }

    public func setHasCompletedOnboarding(_: Bool) {
        // 스텁은 정해진 값만 돌려준다. 쓰기를 확인해야 하는 테스트는 실제 구현과 InMemoryKeyValueStore 를 쓴다.
    }
}
