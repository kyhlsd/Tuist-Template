//
//  SpyBreadcrumbRecorder.swift
//  DiagnosticsTesting
//

import Diagnostics
import os

/// 받은 breadcrumb 를 순서대로 기록하는 `BreadcrumbRecording`.
///
/// `record` 가 동기라 actor 대신 락으로 기록한다.
public final class SpyBreadcrumbRecorder: BreadcrumbRecording {
    private let storage = OSAllocatedUnfairLock<[Breadcrumb]>(initialState: [])

    /// 받은 순서대로 쌓인 breadcrumb.
    public var breadcrumbs: [Breadcrumb] {
        storage.withLock { $0 }
    }

    public init() {}

    public func record(_ breadcrumb: Breadcrumb) {
        storage.withLock { $0.append(breadcrumb) }
    }
}
