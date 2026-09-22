//
//  DiagnosticReporting.swift
//  Domain
//

/// 실패를 보고한다. Data 가 생성 클라이언트를 부르는 `catch` 에서 쓴다.
///
/// 구현은 `DiagnosticReporter`, 테스트용은 DomainTesting 의 `SpyDiagnosticReporter` 다.
public protocol DiagnosticReporting: Sendable {
    /// 결과를 기다리지 않는다. 호출부의 에러 처리를 늦추지 않는다.
    func report(_ failure: DiagnosticFailure)
}
