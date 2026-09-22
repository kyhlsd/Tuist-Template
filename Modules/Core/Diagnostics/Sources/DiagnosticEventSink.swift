//
//  DiagnosticEventSink.swift
//  Diagnostics
//

/// 보고할 실패를 실제로 내보내는 곳.
///
/// 전송 수단(Crashlytics 등)을 바꾸는 경계다. 수단을 바꿔도 이 모듈과 Data 는 그대로다.
/// 중복 억제는 `DiagnosticReporter` 가 맡으므로 구현은 받은 대로 내보낸다.
public protocol DiagnosticEventSink: Sendable {
    /// 동기로 내보낸다. 실패를 돌려주지 않는다(전송 수단이 대기열과 재전송을 맡는다).
    func send(_ failure: DiagnosticFailure)
}
