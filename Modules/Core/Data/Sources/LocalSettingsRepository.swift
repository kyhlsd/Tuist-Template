//
//  LocalSettingsRepository.swift
//  Data
//

import Diagnostics
import Domain
import Persistence

/// 기기 안 키-값 저장소에 설정을 두는 `SettingsRepository` 구현.
///
/// 보고 규칙: 저장소 실패는 삼키지 않고 `reportPersistenceFailure(_:)` 로 보고한 뒤,
/// 읽기는 기본값을 돌려주고 쓰기는 그대로 끝낸다. 화면은 설정 실패를 구분하지 않는다.
public struct LocalSettingsRepository: SettingsRepository {
    private let store: any KeyValueStore
    private let reporter: any DiagnosticReporting

    public init(store: any KeyValueStore, reporter: any DiagnosticReporting) {
        self.store = store
        self.reporter = reporter
    }

    public func hasCompletedOnboarding() -> Bool {
        do {
            return try store.value(for: SettingKeys.hasCompletedOnboarding)
        } catch {
            reporter.reportPersistenceFailure(error)
            return SettingKeys.hasCompletedOnboarding.defaultValue
        }
    }

    public func setHasCompletedOnboarding(_ completed: Bool) {
        do {
            try store.setValue(completed, for: SettingKeys.hasCompletedOnboarding)
        } catch {
            // Bool 의 JSON 인코딩은 실제로 실패하지 않는다. 키 타입이 바뀌어도 빠뜨리지 않게 보고한다.
            reporter.reportPersistenceFailure(error)
        }
    }
}

private enum SettingKeys {
    static let hasCompletedOnboarding = SettingKey<Bool>(name: "hasCompletedOnboarding", defaultValue: false)
}
