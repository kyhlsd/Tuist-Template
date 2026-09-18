//
//  RemoteItemRepository.swift
//  Data
//

import Domain
import Foundation
import Networking

/// 서버에서 항목을 가져오는 `ItemRepository` 구현.
///
/// 기본 URL 은 App 이 설정(Info.plist 의 API_BASE_URL)에서 읽어 주입한다.
public struct RemoteItemRepository: ItemRepository {
    private let client: any HTTPClient
    private let baseURL: URL

    public init(client: any HTTPClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func fetchItems() async throws(ItemError) -> [Item] {
        let request = URLRequest(url: baseURL.appending(path: Endpoint.items))

        let data: Data
        do {
            data = try await client.data(for: request)
        } catch {
            // 전송 실패의 종류는 화면이 구분하지 않으므로 도메인 에러 하나로 모은다.
            throw .unavailable
        }

        do {
            return try JSONDecoder().decode([ItemDTO].self, from: data).map { $0.toDomain() }
        } catch {
            throw .invalidData
        }
    }
}

private enum Endpoint {
    static let items = "items"
}
