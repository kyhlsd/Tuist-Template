//
//  SpyDiagnosticEventSink.swift
//  DiagnosticsTesting
//

import Diagnostics
import os

/// 받은 실패를 순서대로 기록하는 `DiagnosticEventSink`.
///
/// `send` 가 동기라 actor 대신 락으로 기록한다.
public final class SpyDiagnosticEventSink: DiagnosticEventSink {
    private let storage = OSAllocatedUnfairLock<[DiagnosticFailure]>(initialState: [])

    /// 받은 순서대로 쌓인 실패.
    public var sent: [DiagnosticFailure] {
        storage.withLock { $0 }
    }

    public init() {}

    public func send(_ failure: DiagnosticFailure) {
        storage.withLock { $0.append(failure) }
    }
}
