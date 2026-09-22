//
//  DiagnosticReporter.swift
//  Domain
//

import Foundation

/// 같은 실패를 일정 시간 동안 한 번만 싱크로 보낸다.
///
/// fingerprint(operation, 에러 타입, 코드)별로 마지막으로 보낸 시각을 기억한다.
public actor DiagnosticReporter: DiagnosticReporting {
    private let sink: any DiagnosticEventSink
    private let now: @Sendable () -> Date
    private let dedupeInterval: TimeInterval
    private var lastSentAt: [String: Date] = [:]

    /// - Parameters:
    ///   - sink: 억제를 통과한 실패를 받는다.
    ///   - now: 현재 시각. 테스트에서 고정 시계를 넣는다.
    ///   - dedupeInterval: 같은 fingerprint 를 다시 보내기까지의 간격.
    public init(
        sink: any DiagnosticEventSink,
        now: @escaping @Sendable () -> Date = { Date() },
        dedupeInterval: TimeInterval = DiagnosticDefaults.dedupeInterval
    ) {
        self.sink = sink
        self.now = now
        self.dedupeInterval = dedupeInterval
    }

    public nonisolated func report(_ failure: DiagnosticFailure) {
        Task { await handle(failure) }
    }

    /// 억제 여부를 판단하고 통과하면 싱크로 보낸다.
    ///
    /// - Returns: 싱크로 보냈으면 `true`.
    @discardableResult
    func handle(_ failure: DiagnosticFailure) async -> Bool {
        let fingerprint = failure.fingerprint
        let current = now()
        if let last = lastSentAt[fingerprint], current.timeIntervalSince(last) < dedupeInterval {
            return false
        }
        lastSentAt[fingerprint] = current
        sink.send(failure)
        return true
    }
}
