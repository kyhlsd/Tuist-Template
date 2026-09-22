//
//  SpyDiagnosticReporter.swift
//  DomainTesting
//

import Domain
import os

/// 보고를 억제 없이 순서대로 기록하는 `DiagnosticReporting`.
///
/// `report` 가 동기라 actor 대신 락으로 기록한다. 호출 즉시 기록되므로 테스트가 기다릴 필요가 없다.
public final class SpyDiagnosticReporter: DiagnosticReporting {
    private let storage = OSAllocatedUnfairLock<[DiagnosticFailure]>(initialState: [])

    /// 받은 순서대로 쌓인 보고.
    public var reported: [DiagnosticFailure] {
        storage.withLock { $0 }
    }

    public init() {}

    public func report(_ failure: DiagnosticFailure) {
        storage.withLock { $0.append(failure) }
    }
}
