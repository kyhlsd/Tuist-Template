//
//  KeyValueStore.swift
//  Persistence
//

import Foundation

/// 원시 `Data` 를 키로 저장하는 저장소. 인코딩과 기본값은 `SettingKey` 를 받는 extension 이 맡는다.
///
/// 앱은 `UserDefaultsKeyValueStore` 를, 테스트는 `PersistenceTesting` 의 `InMemoryKeyValueStore` 를 쓴다.
///
/// 암호화하지 않고 백업에 포함된다. 토큰 같은 비밀값은 여기 두지 않고 Auth 의 `KeychainTokenStore` 에 둔다.
public protocol KeyValueStore: Sendable {
    /// 저장된 값. 없으면 `nil`.
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    /// 저장된 값을 지운다. 값이 없어도 아무 일도 하지 않는다.
    func removeValue(forKey key: String)
}
