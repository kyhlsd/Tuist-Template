//
//  NetworkError.swift
//  Networking
//

import Foundation

/// 전송 계층의 실패.
///
/// 이 타입은 Networking 과 Data 사이에서만 쓴다. Data 가 도메인 에러로 바꿔서
/// 올리므로 Feature 는 이 타입을 모른다.
public enum NetworkError: Error, Equatable, Sendable {
    /// 요청이 서버에 닿지 못했다. (오프라인, 타임아웃 등)
    case transport(URLError.Code)
    /// HTTP 응답이 아니다.
    case invalidResponse
    /// 2xx 가 아닌 상태 코드.
    case unacceptableStatus(Int)
}
