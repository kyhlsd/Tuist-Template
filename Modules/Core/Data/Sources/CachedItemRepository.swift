//
//  CachedItemRepository.swift
//  Data
//

import Diagnostics
import Domain
import Persistence

/// 다른 `ItemRepository`(보통 `RemoteItemRepository`)를 감싸 오프라인 캐시를 더하는 구현.
///
/// 캐시 정책:
/// - 원격이 성공하면 캐시를 그 결과로 통째로 바꾸고 원격 결과를 돌려준다. 요청이 겹치면 늦게 시작한 요청의 결과가 남는다.
/// - 원격이 `.unavailable` 이면 캐시가 비어 있지 않을 때 캐시 항목을 돌려주고, 비어 있으면 `.unavailable` 을 던진다.
///   호출이 취소됐으면 결과를 버릴 것이므로 캐시를 읽지 않고 그대로 던진다.
/// - 원격이 `.invalidData` 면 캐시로 넘어가지 않는다. 서버가 응답했는데 해석하지 못한 것을 오래된 데이터로 가리지 않는다.
/// - 로그아웃처럼 이전 항목을 보여 주면 안 될 때 App 이 `clearCache()` 를 부른다. 원격은 401 도 `.unavailable` 로
///   올리므로, 비우지 않으면 로그아웃 뒤나 다른 계정에서 이전 계정의 항목이 보인다.
///
/// 캐시는 부가 기능이라 캐시 실패가 결과를 바꾸지 않는다. 쓰기 실패는 보고하고 원격 결과를 돌려주고,
/// 읽기 실패는 보고하고 원래 에러(`.unavailable`)를 던진다.
public struct CachedItemRepository: ItemRepository {
    private let remote: any ItemRepository
    private let cache: any ItemCache
    private let writer: ItemCacheWriter
    private let reporter: any DiagnosticReporting

    public init(remote: any ItemRepository, cache: any ItemCache, reporter: any DiagnosticReporting) {
        self.remote = remote
        self.cache = cache
        writer = ItemCacheWriter(cache: cache)
        self.reporter = reporter
    }

    public func fetchItems() async throws(ItemError) -> [Item] {
        let ticket = await writer.nextTicket()
        let items: [Item]
        do {
            items = try await remote.fetchItems()
        } catch {
            guard error == .unavailable, !Task.isCancelled else {
                throw error
            }
            return try await cachedItems()
        }

        do {
            try await writer.replaceAll(with: items.map(ItemCacheRecord.init(item:)), ticket: ticket)
        } catch {
            reporter.reportPersistenceFailure(error)
        }
        return items
    }

    /// 캐시를 비운다. 이미 시작한 요청의 결과도 이후에 캐시에 쓰지 않는다. 실패하면 보고한다.
    public func clearCache() async {
        do {
            try await writer.removeAll()
        } catch {
            reporter.reportPersistenceFailure(error)
        }
    }

    /// 원격이 `.unavailable` 일 때의 대체 결과. 돌려줄 항목이 없으면 원래 에러를 던진다.
    private func cachedItems() async throws(ItemError) -> [Item] {
        let records: [ItemCacheRecord]
        do {
            records = try await cache.load()
        } catch {
            reporter.reportPersistenceFailure(error)
            throw .unavailable
        }
        guard !records.isEmpty else {
            throw .unavailable
        }
        return records.map { $0.toDomain() }
    }
}
