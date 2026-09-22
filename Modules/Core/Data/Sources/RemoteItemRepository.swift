//
//  RemoteItemRepository.swift
//  Data
//

import Domain
import Networking

/// 서버에서 항목을 가져오는 `ItemRepository` 구현.
///
/// 생성된 `APIProtocol` 에 의존한다. 기본 URL, 인증, 재시도는 App 이 `APIClientFactory` 로 조립한다.
public struct RemoteItemRepository: ItemRepository {
    private let client: any APIProtocol

    public init(client: any APIProtocol) {
        self.client = client
    }

    public func fetchItems() async throws(ItemError) -> [Item] {
        let output: Operations.ListItems.Output
        do {
            output = try await client.listItems()
        } catch {
            // 전송 실패의 종류는 화면이 구분하지 않으므로 도메인 에러 하나로 모은다.
            // 본문 디코딩 실패와 콘텐츠 타입 불일치도 생성 코드가 ClientError 로 던지므로 여기로 온다.
            throw .unavailable
        }

        switch output {
        case let .ok(ok):
            do {
                return try ok.body.json.map { $0.toDomain() }
            } catch {
                // 지금 명세의 200 본문은 JSON 하나뿐이라 여기는 실행되지 않는다. 서버가 보낸 콘텐츠 타입이
                // 명세와 다르거나 디코딩에 실패하면 생성 코드가 ClientError 를 던져 위에서 unavailable 이 된다.
                // 명세에 JSON 이 아닌 콘텐츠 타입이 추가되면 그 본문이 여기로 와 invalidData 가 된다.
                throw .invalidData
            }
        case .unauthorized, .undocumented:
            throw .unavailable
        }
    }
}
