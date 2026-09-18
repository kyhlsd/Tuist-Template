//
//  AppContainer.swift
//  TuistApp
//

import Data
import Domain
import Foundation
import Networking

/// 앱의 조립 지점(composition root).
///
/// 구현 타입(`URLSessionHTTPClient`, `RemoteItemRepository`)을 아는 곳은 여기뿐이다.
/// 피처는 Domain 프로토콜만 받는다. 피처별 화면 생성은 `AppContainer+<Feature>.swift` 에 둔다.
@MainActor
final class AppContainer {
    let itemRepository: any ItemRepository

    init(configuration: AppConfiguration) {
        let client = URLSessionHTTPClient(session: .shared)
        itemRepository = RemoteItemRepository(client: client, baseURL: configuration.apiBaseURL)
    }
}
