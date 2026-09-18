//
//  HTTPClient.swift
//  Networking
//

import Foundation

/// HTTP 요청을 보내고 응답 본문을 돌려준다.
///
/// Data 의 Repository 는 이 프로토콜에만 의존한다. 테스트에서는 스텁으로 바꾼다.
public protocol HTTPClient: Sendable {
    /// 2xx 응답의 본문을 돌려준다. 그 외에는 `NetworkError` 를 던진다.
    func data(for request: URLRequest) async throws(NetworkError) -> Data
}
