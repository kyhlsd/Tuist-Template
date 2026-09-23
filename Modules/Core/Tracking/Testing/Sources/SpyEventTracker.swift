//
//  SpyEventTracker.swift
//  TrackingTesting
//

import os
import Tracking

/// 받은 이벤트를 순서대로 기록하는 `EventTracking`.
///
/// `track` 이 동기라 actor 대신 락으로 기록한다.
public final class SpyEventTracker: EventTracking {
    private let storage = OSAllocatedUnfairLock<[TrackingEvent]>(initialState: [])

    /// 받은 순서대로 쌓인 이벤트.
    public var events: [TrackingEvent] {
        storage.withLock { $0 }
    }

    public init() {}

    public func track(_ event: TrackingEvent) {
        storage.withLock { $0.append(event) }
    }
}
