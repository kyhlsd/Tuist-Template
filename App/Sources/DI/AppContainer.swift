//
//  AppContainer.swift
//  TuistApp
//

import Data
import Diagnostics
import Domain
import FeatureFlags
import Foundation
import Networking
import os
import Tracking

/// 앱의 조립 지점(composition root).
///
/// 구현 타입(`APIClientFactory`, `KeychainTokenStore`, `RemoteItemRepository`,
/// `DiagnosticReporter`, `CrashlyticsDiagnosticSink`, `LoggerDiagnosticSink`, `NetworkBreadcrumbAdapter`,
/// `FirebaseEventTracker`, `LoggerEventTracker`, `RemoteConfigFeatureFlagProvider`, `DefaultFeatureFlagProvider`)을
/// 아는 곳은 여기뿐이다.
/// 피처는 Domain 프로토콜만 받는다. 피처별 화면 생성은 `AppContainer+<Feature>.swift` 에 둔다.
@MainActor
final class AppContainer {
    let itemRepository: any ItemRepository
    /// 피처에 넘길 이벤트 기록기. 앱 전체에서 하나를 쓴다.
    let eventTracker: any EventTracking
    /// 피처에 넘길 플래그 제공자. 앱 전체에서 하나를 쓴다.
    let featureFlags: any FeatureFlagProviding

    /// 앱 수명 동안 하나만 둔다. 설정(타임아웃 등)은 `APIClientFactory.makeSession()` 이 정한다.
    private let session: URLSession

    init(configuration: AppConfiguration) {
        // 이 컨테이너는 didFinishLaunching 보다 먼저 만들어진다. 싱크를 고르기 전에 초기화해야 한다.
        let firebaseDecision = FirebaseBootstrap.configureIfAvailable()

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("번들 ID 가 없습니다. Keychain 서비스 이름과 로그 subsystem 을 정할 수 없습니다.")
        }

        let diagnosticSink = Self.makeDiagnosticSink(
            firebaseDecision: firebaseDecision,
            logger: Logger(subsystem: bundleIdentifier, category: LogCategory.diagnostics)
        )
        // 생성 클라이언트를 부르는 Repository 가 함께 쓴다. 같은 실패의 중복 억제를 앱 전체에서 공유한다.
        let diagnosticReporter = DiagnosticReporter(sink: diagnosticSink)
        eventTracker = Self.makeEventTracker(
            firebaseDecision: firebaseDecision,
            logger: Logger(subsystem: bundleIdentifier, category: LogCategory.tracking)
        )
        featureFlags = Self.makeFeatureFlagProvider(firebaseDecision: firebaseDecision) {
            RemoteConfigFeatureFlagProvider.fetchAndActivate(
                logger: Logger(subsystem: bundleIdentifier, category: LogCategory.featureFlags)
            )
        }

        session = APIClientFactory.makeSession()
        let logger = Logger(subsystem: bundleIdentifier, category: LogCategory.session)
        let client = APIClientFactory.make(
            baseURL: configuration.apiBaseURL,
            session: session,
            tokenStore: KeychainTokenStore(service: bundleIdentifier),
            logSubsystem: bundleIdentifier,
            activityObserver: NetworkBreadcrumbAdapter(recorder: diagnosticSink),
            onSessionExpired: {
                // 로그인 화면이 아직 없으므로 로그만 남긴다. 화면 전환은 범위 밖이다.
                logger.notice("세션이 만료되어 저장된 토큰을 지웠습니다.")
            }
        )
        itemRepository = RemoteItemRepository(client: client, reporter: diagnosticReporter)
    }

    /// Firebase 를 초기화했으면 Crashlytics 로, 아니면 로그로만 남긴다. 건너뛴 이유를 로그로 남긴다.
    ///
    /// Release 에서 실제로 수집되는지가 이 분기로 정해지므로 테스트한다(`AppContainerDiagnosticSinkTests`).
    static func makeDiagnosticSink(
        firebaseDecision: FirebaseBootstrap.Decision,
        logger: Logger
    ) -> any DiagnosticEventSink & BreadcrumbRecording {
        switch firebaseDecision {
        case .configure:
            return CrashlyticsDiagnosticSink()
        case .skipDebug:
            logger.notice("Firebase 초기화 건너뜀(Debug 빌드). 진단은 로그로만 남깁니다.")
        case .skipMissingConfigFile:
            logger.notice("Firebase 초기화 건너뜀(설정 파일 없음). 진단은 로그로만 남깁니다.")
        }
        return LoggerDiagnosticSink(logger: logger)
    }

    /// Firebase 를 초기화했으면 Analytics 로, 아니면 로그로만 남긴다.
    ///
    /// 건너뛴 이유는 `makeDiagnosticSink` 가 이미 남기므로 여기서는 남기지 않는다(`AppContainerEventTrackerTests`).
    static func makeEventTracker(firebaseDecision: FirebaseBootstrap.Decision, logger: Logger) -> any EventTracking {
        switch firebaseDecision {
        case .configure:
            FirebaseEventTracker()
        case .skipDebug, .skipMissingConfigFile:
            LoggerEventTracker(logger: logger)
        }
    }

    /// Firebase 를 초기화했으면 원격 값을 받기 시작하고 Remote Config 값을, 아니면 선언된 기본값을 쓴다.
    ///
    /// 받기 시작과 제공자 선택을 한 `switch` 에서 정한다. 둘이 어긋나면 Release 에서 값을 한 번도 받지 않은 채
    /// Remote Config 를 읽게 된다. 분기는 `AppContainerFeatureFlagProviderTests` 가 고정한다.
    /// - Parameter startFetch: `.configure` 일 때만 곧바로 한 번 부른다.
    static func makeFeatureFlagProvider(
        firebaseDecision: FirebaseBootstrap.Decision,
        startFetch: () -> Void
    ) -> any FeatureFlagProviding {
        switch firebaseDecision {
        case .configure:
            startFetch()
            return RemoteConfigFeatureFlagProvider()
        case .skipDebug, .skipMissingConfigFile:
            return DefaultFeatureFlagProvider()
        }
    }
}

private enum LogCategory {
    static let session = "Session"
    static let diagnostics = "Diagnostics"
    static let tracking = "Tracking"
    static let featureFlags = "FeatureFlags"
}
