//
//  PersistenceDemoModel.swift
//  PersistenceDemo
//

import Observation
import Persistence

/// 캐시 항목과 실행 횟수를 읽고 쓰는 데모 화면 상태.
///
/// 실패는 삼키지 않고 `lastError` 에 남겨 화면에 보여 준다. 동작을 시작할 때 비우므로 화면의 에러는 마지막 동작의 것이다.
@MainActor
@Observable
final class PersistenceDemoModel {
    private(set) var records: [ItemCacheRecord] = []
    private(set) var launchCount = Keys.launchCount.defaultValue
    private(set) var lastError: PersistenceError?
    /// `.onDisk` 를 열지 못한 이유. 값이 있으면 `.inMemory` 로 폴백했고 재실행 뒤에 값이 남지 않는다.
    let onDiskError: PersistenceError?

    private let cache: any ItemCache
    private let settings: any KeyValueStore

    init(cache: any ItemCache, settings: any KeyValueStore, onDiskError: PersistenceError?) {
        self.cache = cache
        self.settings = settings
        self.onDiskError = onDiskError
    }

    /// 샘플로 통째로 바꾼다. 샘플에는 id 가 겹치는 항목이 하나 있어 중복 제거를 확인할 수 있다.
    func replaceWithSamples() async {
        lastError = nil
        do {
            try await cache.replaceAll(with: Samples.records)
        } catch {
            lastError = error
        }
        await reload()
    }

    func removeAll() async {
        lastError = nil
        do {
            try await cache.removeAll()
        } catch {
            lastError = error
        }
        await reload()
    }

    /// 목록만 다시 읽는다. 앞선 동작의 에러를 지우지 않도록 `lastError` 는 실패할 때만 바꾼다.
    ///
    /// 화면 진입 때도 이것을 부른다. 화면 진입은 사용자 동작이 아니므로, 뷰가 뜨기 전에 난
    /// 실행 횟수 증가 실패를 지우면 안 된다.
    func reload() async {
        do {
            records = try await cache.load()
        } catch {
            lastError = error
        }
    }

    func incrementLaunchCount() {
        lastError = nil
        do {
            let next = try settings.value(for: Keys.launchCount) + 1
            try settings.setValue(next, for: Keys.launchCount)
            launchCount = next
        } catch {
            lastError = error
        }
    }

    /// 저장된 값을 지운 뒤 다시 읽어 기본값으로 돌아왔는지 보여 준다.
    func resetLaunchCount() {
        lastError = nil
        settings.removeValue(forKey: Keys.launchCount.name)
        do {
            launchCount = try settings.value(for: Keys.launchCount)
        } catch {
            lastError = error
        }
    }
}

private enum Keys {
    static let launchCount = SettingKey(name: "demo.launchCount", defaultValue: 0)
}

private enum Samples {
    static let count = 5

    /// 고유 항목 `count` 개 뒤에 첫 항목과 id 가 같은 항목 하나를 붙인다. 저장 후에는 `count` 개만 남아야 한다.
    static var records: [ItemCacheRecord] {
        let unique = (1 ... count).map { ItemCacheRecord(id: "item-\($0)", title: "샘플 \($0)") }
        let duplicate = ItemCacheRecord(id: "item-1", title: "중복 id — 저장되면 안 됩니다")
        return unique + [duplicate]
    }
}
