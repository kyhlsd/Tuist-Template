//
//  KeyValueStoreCodableTests.swift
//  PersistenceTests
//

import Foundation
import Persistence
import PersistenceTesting
import Testing

@Suite("KeyValueStore+Codable")
struct KeyValueStoreCodableTests {
    private struct Profile: Codable, Equatable {
        let nickname: String
        let age: Int
    }

    private let flagKey = SettingKey<Bool>(name: "flag", defaultValue: false)
    private let profileKey = SettingKey<Profile>(name: "profile", defaultValue: Profile(nickname: "", age: 0))

    @Test("값이 없으면 기본값을 돌려준다")
    func value_whenMissing_returnsDefault() throws {
        let store = InMemoryKeyValueStore()

        #expect(try store.value(for: flagKey) == false)
    }

    @Test("저장한 Bool 을 다시 읽으면 같은 값이다")
    func value_afterSettingBool_returnsSavedValue() throws {
        let store = InMemoryKeyValueStore()

        try store.setValue(true, for: flagKey)

        #expect(try store.value(for: flagKey) == true)
    }

    @Test("저장한 Codable 구조체를 다시 읽으면 같은 값이다")
    func value_afterSettingStruct_returnsSavedValue() throws {
        let store = InMemoryKeyValueStore()
        let profile = Profile(nickname: "tester", age: 30)

        try store.setValue(profile, for: profileKey)

        #expect(try store.value(for: profileKey) == profile)
    }

    @Test("해석할 수 없는 값이 있으면 decodingFailed 를 던진다")
    func value_whenDataIsCorrupted_throwsDecodingFailed() {
        let store = InMemoryKeyValueStore(values: [flagKey.name: Data("not json".utf8)])

        #expect(throws: PersistenceError.decodingFailed) {
            try store.value(for: flagKey)
        }
    }

    @Test("값을 지운 뒤에는 기본값을 돌려준다")
    func value_afterRemoving_returnsDefault() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue(true, for: flagKey)

        store.removeValue(forKey: flagKey.name)

        #expect(try store.value(for: flagKey) == false)
    }
}
