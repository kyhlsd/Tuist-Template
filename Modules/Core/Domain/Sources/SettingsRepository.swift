//
//  SettingsRepository.swift
//  Domain
//

/// 사용자 설정 저장소.
///
/// Domain 은 프로토콜만 선언한다. 구현은 Data 의 `LocalSettingsRepository`,
/// 테스트·데모용 스텁은 DomainTesting 의 `StubSettingsRepository` 다.
/// 어떤 구현을 쓸지는 App 이 정한다.
///
/// 화면이 설정 에러를 구분할 이유가 없으므로 던지지 않는다. 읽지 못하면 구현이 보고하고 기본값을 돌려준다.
public protocol SettingsRepository: Sendable {
    /// 온보딩을 끝냈는지. 저장된 적이 없으면 `false`.
    func hasCompletedOnboarding() -> Bool
    func setHasCompletedOnboarding(_ completed: Bool)
}
