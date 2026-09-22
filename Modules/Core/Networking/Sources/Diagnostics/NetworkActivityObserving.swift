//
//  NetworkActivityObserving.swift
//  Networking
//

/// 요청이 끝날 때마다 요약을 받는다. App 이 breadcrumb 로 바꿔 진단 기록에 남긴다.
///
/// Networking 은 Domain 을 모르므로 이 프로토콜로 바깥에 알린다.
public protocol NetworkActivityObserving: Sendable {
    /// 요청 하나가 끝났을 때(성공, 실패 모두) 로그를 남긴 뒤 동기로 부른다. 순서가 지켜진다.
    ///
    /// 요청 경로에서 불리므로 오래 걸리는 일을 하지 않는다.
    func requestFinished(_ record: NetworkRequestRecord)
}
