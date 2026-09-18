//
//  RemoteItemRepositoryTests.swift
//  DataTests
//

import Data
import Domain
import Foundation
import Networking
import Testing

@Suite("RemoteItemRepository")
struct RemoteItemRepositoryTests {
    private let baseURL = URL(filePath: "/api")

    @Test("응답 본문을 도메인 항목으로 변환한다")
    func fetchItems_validResponse_returnsItems() async throws {
        let body = Data(#"[{"id":"1","title":"첫 번째"}]"#.utf8)
        let repository = RemoteItemRepository(client: StubHTTPClient(result: .success(body)), baseURL: baseURL)

        let items = try await repository.fetchItems()

        #expect(items == [Item(id: "1", title: "첫 번째")])
    }

    @Test("전송 실패는 unavailable 로 바뀐다")
    func fetchItems_networkFailure_throwsUnavailable() async {
        let client = StubHTTPClient(result: .failure(.unacceptableStatus(500)))
        let repository = RemoteItemRepository(client: client, baseURL: baseURL)

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
    }

    @Test("해석할 수 없는 본문은 invalidData 로 바뀐다")
    func fetchItems_malformedBody_throwsInvalidData() async {
        let client = StubHTTPClient(result: .success(Data("not json".utf8)))
        let repository = RemoteItemRepository(client: client, baseURL: baseURL)

        await #expect(throws: ItemError.invalidData) {
            try await repository.fetchItems()
        }
    }
}

/// 정해진 결과를 돌려주는 `HTTPClient`. 이 파일에서만 쓰므로 Testing 모듈로 빼지 않는다.
private struct StubHTTPClient: HTTPClient {
    let result: Result<Data, NetworkError>

    func data(for _: URLRequest) async throws(NetworkError) -> Data {
        try result.get()
    }
}
