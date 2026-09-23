//
//  TrackingEvent.swift
//  Tracking
//

/// 기록할 이벤트 하나.
///
/// 이름은 피처 모듈의 `enum` 네임스페이스에 상수로 둔다. 이름과 파라미터 제약은 전송 수단마다 달라서
/// 이 모듈은 검증하지 않는다(README 참고).
public struct TrackingEvent: Sendable, Equatable {
    public let name: String
    public let parameters: [String: TrackingValue]

    public init(name: String, parameters: [String: TrackingValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}
