//
//  NetworkDefaults.swift
//  Networking
//

import Foundation

/// 네트워크 계층의 기본값. 값을 바꿀 때는 여기만 고친다.
enum NetworkDefaults {
    /// 데이터가 오가지 않은 채 기다리는 최대 시간(전체 시간이 아니다). 응답 없이 멈춘 서버를 잡는다.
    static let requestTimeout: TimeInterval = 15
    /// 요청 하나의 전체 시간 상한. 기본값(7일)을 화면에서 기다릴 만한 시간으로 줄인다.
    static let resourceTimeout: TimeInterval = 30
    /// 오프라인이면 기다리지 않고 바로 실패한다. 화면에 "다시 시도"가 있으므로 사용자가 다시 부른다.
    /// 백그라운드·비긴급 작업이 생기면 그 작업용 세션에서만 켠다.
    static let waitsForConnectivity = false
    static let maxRetries = 2
    static let retryBaseDelay: Duration = .milliseconds(500)
    /// 요청 로그와 토큰 저장소 실패 로그의 category.
    static let logCategory = "Networking"

    static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = waitsForConnectivity
        return configuration
    }
}
