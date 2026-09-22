//
//  AppContainer.swift
//  TuistApp
//

import Data
import Domain
import Foundation
import Networking
import os

/// 앱의 조립 지점(composition root).
///
/// 구현 타입(`APIClientFactory`, `KeychainTokenStore`, `RemoteItemRepository`)을 아는 곳은 여기뿐이다.
/// 피처는 Domain 프로토콜만 받는다. 피처별 화면 생성은 `AppContainer+<Feature>.swift` 에 둔다.
@MainActor
final class AppContainer {
    let itemRepository: any ItemRepository

    /// 앱 수명 동안 하나만 둔다. 설정(타임아웃 등)은 `APIClientFactory.makeSession()` 이 정한다.
    private let session: URLSession

    init(configuration: AppConfiguration) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("번들 ID 가 없습니다. Keychain 서비스 이름과 로그 subsystem 을 정할 수 없습니다.")
        }

        session = APIClientFactory.makeSession()
        let logger = Logger(subsystem: bundleIdentifier, category: LogCategory.session)
        let client = APIClientFactory.make(
            baseURL: configuration.apiBaseURL,
            session: session,
            tokenStore: KeychainTokenStore(service: bundleIdentifier),
            logSubsystem: bundleIdentifier,
            onSessionExpired: {
                // 로그인 화면이 아직 없으므로 로그만 남긴다. 화면 전환은 범위 밖이다.
                logger.notice("세션이 만료되어 저장된 토큰을 지웠습니다.")
            }
        )
        itemRepository = RemoteItemRepository(client: client)
    }
}

private enum LogCategory {
    static let session = "Session"
}
