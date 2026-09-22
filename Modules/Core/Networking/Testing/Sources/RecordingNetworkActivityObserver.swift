//
//  RecordingNetworkActivityObserver.swift
//  NetworkingTesting
//

import Networking
import os

/// 받은 요청 요약을 순서대로 기록하는 `NetworkActivityObserving`.
///
/// `requestFinished` 가 동기라 actor 대신 락으로 기록한다.
public final class RecordingNetworkActivityObserver: NetworkActivityObserving {
    private let storage = OSAllocatedUnfairLock<[NetworkRequestRecord]>(initialState: [])

    /// 받은 순서대로 쌓인 요약.
    public var records: [NetworkRequestRecord] {
        storage.withLock { $0 }
    }

    public init() {}

    public func requestFinished(_ record: NetworkRequestRecord) {
        storage.withLock { $0.append(record) }
    }
}
