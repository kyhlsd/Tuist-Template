//
//  AppContainer.swift
//  TuistApp
//

import Auth
import Data
import Diagnostics
import Domain
import FeatureFlags
import Foundation
import Networking
import os
import Persistence
import Tracking

/// 앱의 조립 지점(composition root).
///
/// 구현 타입(`APIClientFactory`, `AuthSession`, `KeychainTokenStore`, `RemoteItemRepository`, `RemoteAuthRepository`,
/// `CachedItemRepository`, `LocalSettingsRepository`, `LocalDatabase`, `SwiftDataItemCache`, `UserDefaultsKeyValueStore`,
/// `DiagnosticReporter`, `CrashlyticsDiagnosticSink`, `LoggerDiagnosticSink`, `NetworkBreadcrumbAdapter`,
/// `FirebaseEventTracker`, `LoggerEventTracker`, `RemoteConfigFeatureFlagProvider`, `DefaultFeatureFlagProvider`)을
/// 아는 곳은 여기뿐이다.
/// 피처는 Domain 프로토콜만 받는다. 피처별 화면 생성은 `AppContainer+<Feature>.swift` 에 둔다.
@MainActor
final class AppContainer {
    /// 원격 결과를 오프라인 캐시에 남기고, 원격을 쓸 수 없으면 캐시를 돌려준다.
    let itemRepository: any ItemRepository
    /// 기기 안 설정(온보딩 완료 여부 등).
    let settingsRepository: any SettingsRepository
    /// 로그인·로그아웃과 세션 상태. 인증 미들웨어와 같은 `AuthSession` 을 쓴다. 로그인 상태가 아니게 되면 항목 캐시를 비운다.
    let authRepository: any AuthRepository
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
        let localDatabase = Self.makeLocalDatabase(reporter: diagnosticReporter)
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
        let activityObserver = NetworkBreadcrumbAdapter(recorder: diagnosticSink)
        let authSession = AuthSession(
            store: KeychainTokenStore(service: bundleIdentifier),
            refresh: APIClientFactory.makeTokenRefresh(
                baseURL: configuration.apiBaseURL,
                session: session,
                logSubsystem: bundleIdentifier,
                activityObserver: activityObserver
            ),
            // 만료 로그는 AuthSession 이 남긴다. 로그인 화면이 아직 없으므로 화면 전환은 범위 밖이다.
            logger: Logger(subsystem: bundleIdentifier, category: LogCategory.session)
        )
        let client = APIClientFactory.make(
            baseURL: configuration.apiBaseURL,
            session: session,
            tokenProvider: authSession,
            logSubsystem: bundleIdentifier,
            activityObserver: activityObserver
        )
        let cachedItemRepository = CachedItemRepository(
            remote: RemoteItemRepository(client: client, reporter: diagnosticReporter),
            cache: SwiftDataItemCache(database: localDatabase),
            reporter: diagnosticReporter
        )
        itemRepository = cachedItemRepository
        authRepository = RemoteAuthRepository(client: client, session: authSession, reporter: diagnosticReporter)
        settingsRepository = LocalSettingsRepository(store: UserDefaultsKeyValueStore(), reporter: diagnosticReporter)
        Self.startClearingItemCache(of: cachedItemRepository, whenSignedOutIn: authRepository)
    }

    /// 세션 상태를 구독해 로그인 상태가 아니게 될 때마다 항목 캐시를 비운다. 세션 상태 스트림은 끝나지 않으므로 앱 수명 동안 돈다.
    ///
    /// 앱은 돌려받은 Task 를 버린다. 테스트는 끝나는 상태 스트림을 넘기고 Task 를 기다려 연결을 확인한다
    /// (`AppContainerItemCacheInvalidationTests`).
    @discardableResult
    static func startClearingItemCache(
        of repository: CachedItemRepository,
        whenSignedOutIn authRepository: any AuthRepository
    ) -> Task<Void, Never> {
        Task {
            await clearItemCacheWhenSignedOut(statuses: authRepository.sessionStatuses(), clear: repository.clearCache)
        }
    }

    /// 세션이 로그인 상태가 아니게 되면(로그아웃·만료) 항목 캐시를 비운다. `statuses` 가 끝날 때까지 돈다.
    ///
    /// 원격은 401 도 `.unavailable` 로 올리므로, 비우지 않으면 로그아웃 뒤나 다른 계정에서 이전 계정의 항목이 캐시에서 나온다.
    /// 첫 상태(현재 상태)가 `.signedOut` 이면 앱 시작 때도 비운다. 분기는 `AppContainerItemCacheInvalidationTests` 가 고정한다.
    static func clearItemCacheWhenSignedOut(statuses: AsyncStream<SessionStatus>, clear: () async -> Void) async {
        for await status in statuses {
            switch status {
            case .signedIn:
                continue
            case .signedOut, .expired:
                await clear()
            }
        }
    }

    /// 디스크 저장소를 연다. 열지 못하면 보고하고 메모리 저장소로 연다.
    ///
    /// 캐시 때문에 앱 실행이 막히면 안 된다. 폴백해도 캐시가 앱 수명 동안만 남을 뿐 동작은 원격만 쓸 때와 같다.
    /// 분기는 `AppContainerLocalDatabaseTests` 가 고정한다.
    /// - Parameter open: 저장소를 여는 방법. 테스트가 디스크 실패를 흉내 낼 때만 바꾼다.
    static func makeLocalDatabase(
        reporter: any DiagnosticReporting,
        open: (LocalDatabase.Location) throws(PersistenceError) -> LocalDatabase = LocalDatabase.init(location:)
    ) -> LocalDatabase {
        do {
            return try open(.onDisk)
        } catch {
            reporter.reportPersistenceFailure(error)
        }
        do {
            return try open(.inMemory)
        } catch {
            preconditionFailure("메모리 저장소도 열 수 없습니다(\(error)). 스키마 선언이 잘못됐습니다.")
        }
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
