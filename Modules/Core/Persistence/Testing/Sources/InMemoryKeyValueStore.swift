//
//  InMemoryKeyValueStore.swift
//  PersistenceTesting
//

import Foundation
import os
import Persistence

/// 메모리에만 값을 두는 `KeyValueStore`. 테스트에서 UserDefaults 대신 쓴다.
///
/// `KeyValueStore` 가 동기 프로토콜이라 actor 로 만들 수 없고 `Mutex` 는 iOS 18 부터라,
/// `Sendable` 인 `OSAllocatedUnfairLock` 으로 상태를 감싼다.
public final class InMemoryKeyValueStore: KeyValueStore {
    private let storage: OSAllocatedUnfairLock<[String: Data]>

    public init(values: [String: Data] = [:]) {
        storage = OSAllocatedUnfairLock(initialState: values)
    }

    public func data(forKey key: String) -> Data? {
        storage.withLock { $0[key] }
    }

    public func set(_ data: Data, forKey key: String) {
        storage.withLock { $0[key] = data }
    }

    public func removeValue(forKey key: String) {
        storage.withLock { _ = $0.removeValue(forKey: key) }
    }
}
