//
//  EventTracking.swift
//  Tracking
//

/// 이벤트를 기록하는 곳.
///
/// 전송 수단(Firebase Analytics 등)을 바꾸는 경계다. 피처는 이 프로토콜을 생성자로 받고 수단을 모른다.
public protocol EventTracking: Sendable {
    /// 동기로 기록한다. 실패를 돌려주지 않는다(전송 수단이 대기열과 재전송을 맡는다).
    func track(_ event: TrackingEvent)
}
