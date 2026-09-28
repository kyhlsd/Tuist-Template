//
//  UserDefaultsKeyValueStore.swift
//  Persistence
//

import Foundation

/// `UserDefaults` 에 그대로 넘기는 `KeyValueStore`. 모든 키 앞에 접두사를 붙여 SDK 가 쓰는 키와 섞이지 않게 한다.
///
/// `UserDefaults` 는 SDK 에서 `Sendable` 이 아니므로 인스턴스 대신 `suiteName` 만 보관하고 호출할 때마다 얻는다.
/// 인코딩·기본값 로직이 없는 얇은 어댑터라 단위 테스트하지 않는다(디스크에 쓰기 때문이다).
public struct UserDefaultsKeyValueStore: KeyValueStore {
    private let suiteName: String?

    /// - Parameter suiteName: `nil` 이면 `UserDefaults.standard`. 앱 그룹 공유는 아직 쓰지 않는다.
    public init(suiteName: String? = nil) {
        // 잘못된 suite 이름은 첫 읽기·쓰기가 아니라 조립 시점(App)에 드러나게 한다.
        if let suiteName, UserDefaults(suiteName: suiteName) == nil {
            preconditionFailure(Self.rejectedSuiteMessage(suiteName))
        }
        self.suiteName = suiteName
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: Self.storageKey(key))
    }

    public func set(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: Self.storageKey(key))
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: Self.storageKey(key))
    }

    private var defaults: UserDefaults {
        guard let suiteName else {
            return .standard
        }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure(Self.rejectedSuiteMessage(suiteName))
        }
        return defaults
    }

    private static func rejectedSuiteMessage(_ suiteName: String) -> String {
        "UserDefaults 가 suiteName(\(suiteName))을 거부했다. 앱의 번들 ID 는 suite 이름으로 쓸 수 없다."
    }

    private static func storageKey(_ key: String) -> String {
        KeyPrefix.value + key
    }
}

private enum KeyPrefix {
    static let value = "persistence."
}
