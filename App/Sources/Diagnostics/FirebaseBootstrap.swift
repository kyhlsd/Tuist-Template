//
//  FirebaseBootstrap.swift
//  TuistApp
//

import FirebaseCore
import Foundation

/// Firebase 를 초기화할 수 있을 때만 초기화한다.
///
/// Debug 는 수집하지 않는다(시끄럽고 dSYM 도 없다. 테스트 호스트도 Debug 다).
/// `GoogleService-Info.plist` 가 없으면 `FirebaseApp.configure()` 가 크래시하므로 Release 도 건너뛴다.
/// 파일을 `App/Resources/` 에 넣으면 다음 Release 빌드부터 켜진다.
enum FirebaseBootstrap {
    enum Decision: Equatable {
        case configure
        case skipDebug
        case skipMissingConfigFile
    }

    /// 초기화 여부를 정한다. 판정만 분리해 테스트한다.
    static func decision(isDebug: Bool, hasConfigFile: Bool) -> Decision {
        if isDebug {
            return .skipDebug
        }
        return hasConfigFile ? .configure : .skipMissingConfigFile
    }

    /// 조건이 맞으면 Firebase 를 초기화한다. `FirebaseApp.configure()` 는 메인 스레드에서 불러야 한다.
    ///
    /// - Returns: 내린 결정. `.configure` 면 초기화했다. 건너뛴 이유는 호출부가 로그로 남긴다.
    @MainActor
    static func configureIfAvailable(bundle: Bundle = .main) -> Decision {
        #if DEBUG
            let isDebug = true
        #else
            let isDebug = false
        #endif
        let hasConfigFile = bundle.path(forResource: ConfigFile.name, ofType: ConfigFile.type) != nil
        let decision = decision(isDebug: isDebug, hasConfigFile: hasConfigFile)
        if decision == .configure {
            FirebaseApp.configure()
        }
        return decision
    }
}

private enum ConfigFile {
    static let name = "GoogleService-Info"
    static let type = "plist"
}
