//
//  ItemCacheRecord+UniqueID.swift
//  Persistence
//

extension [ItemCacheRecord] {
    /// id 가 겹치면 처음 나온 것만 남긴다. 순서는 유지한다.
    ///
    /// `@Attribute(.unique)` 가 겹치는 id 를 어떻게 합칠지는 OS 버전마다 다를 수 있어 넣기 전에 직접 정한다.
    func removingDuplicateIDs() -> [ItemCacheRecord] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
