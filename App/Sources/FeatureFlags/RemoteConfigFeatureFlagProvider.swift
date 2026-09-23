//
//  RemoteConfigFeatureFlagProvider.swift
//  TuistApp
//

import FeatureFlags
import FirebaseRemoteConfig
import os

/// 플래그 값을 Firebase Remote Config 에서 읽는다. 값이 없으면 선언된 기본값을 돌려준다.
///
/// `RemoteConfig` 인스턴스는 Sendable 이 아니므로 저장하지 않고 호출할 때마다 받는다.
/// 만들기만 해서는 Firebase 를 부르지 않는다. Firebase 를 초기화한 뒤에만 쓴다(`FirebaseBootstrap`).
///
/// 기본값은 `FeatureFlag.defaultValue` 가 유일한 출처라 `setDefaults` 를 쓰지 않는다.
struct RemoteConfigFeatureFlagProvider: FeatureFlagProviding {
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        let value = RemoteConfig.remoteConfig().configValue(forKey: flag.key)
        return Self.resolve(source: value.source, remoteValue: value.boolValue, defaultValue: flag.defaultValue)
    }

    /// `.static` 은 받거나 적용한 값이 없다는 뜻이므로 기본값을 쓴다. 그 밖에는 Remote Config 의 값을 쓴다.
    static func resolve(source: RemoteConfigSource, remoteValue: Bool, defaultValue: Bool) -> Bool {
        switch source {
        case .static:
            defaultValue
        case .remote, .default:
            remoteValue
        @unknown default:
            defaultValue
        }
    }

    /// 원격 값을 한 번 받아서 곧바로 적용하고 결과를 로그로 남긴다.
    ///
    /// 실패해도 다른 처리는 하지 않는다. 지난 실행에서 적용한 값이나 기본값으로 계속 동작하고,
    /// 다음 실행에서 다시 받는다.
    static func fetchAndActivate(logger: Logger) {
        RemoteConfig.remoteConfig().fetchAndActivate { status, error in
            if let error {
                logger.error("\(LogText.failed, privacy: .public) \(error.localizedDescription, privacy: .public)")
                return
            }
            switch status {
            case .successFetchedFromRemote:
                logger.info("\(LogText.fetchedFromRemote, privacy: .public)")
            case .successUsingPreFetchedData:
                logger.info("\(LogText.usingPreFetchedData, privacy: .public)")
            case .error:
                logger.error("\(LogText.failed, privacy: .public)")
            @unknown default:
                logger.notice("\(LogText.unknownStatus, privacy: .public) \(status.rawValue, privacy: .public)")
            }
        }
    }
}

private enum LogText {
    static let fetchedFromRemote = "Remote Config 새 값을 받아 적용했습니다."
    static let usingPreFetchedData = "Remote Config 받아둔 값을 적용했습니다(최소 간격 이내)."
    static let failed = "Remote Config 받기 실패. 적용된 값이나 기본값으로 계속합니다."
    static let unknownStatus = "Remote Config 알 수 없는 상태:"
}
