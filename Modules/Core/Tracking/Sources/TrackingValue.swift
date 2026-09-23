//
//  TrackingValue.swift
//  Tracking
//

/// 이벤트 파라미터 값. 전송 수단이 받는 문자열과 숫자만 담는다.
///
/// Bool 은 문자열과 숫자 중 어느 쪽으로 보낼지 모호해서 넣지 않는다. 필요하면 호출부가 정해서 넣는다.
public enum TrackingValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
}
