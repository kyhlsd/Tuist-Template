//
//  KeyValueStore+Codable.swift
//  Persistence
//

import Foundation

public extension KeyValueStore {
    /// `key` 에 저장된 값. 없으면 `key.defaultValue`.
    ///
    /// - Throws: 저장된 값을 `Value` 로 해석할 수 없으면 `.decodingFailed`.
    func value<Value>(for key: SettingKey<Value>) throws(PersistenceError) -> Value {
        guard let data = data(forKey: key.name) else {
            return key.defaultValue
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            // 원인은 PersistenceError 의 Equatable 을 위해 담지 않는다. 보고는 부르는 쪽이 한다.
            throw .decodingFailed
        }
    }

    /// `value` 를 JSON 으로 인코딩해 `key` 에 저장한다.
    ///
    /// - Throws: 인코딩할 수 없으면 `.encodingFailed`.
    func setValue<Value>(_ value: Value, for key: SettingKey<Value>) throws(PersistenceError) {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            // 원인은 PersistenceError 의 Equatable 을 위해 담지 않는다. 보고는 부르는 쪽이 한다.
            throw .encodingFailed
        }
        set(data, forKey: key.name)
    }
}
