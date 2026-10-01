//
//  AppContainerItemCacheInvalidationTests.swift
//  TuistAppTests
//

import Data
import DiagnosticsTesting
import Domain
import DomainTesting
import Persistence
import PersistenceTesting
import Testing
@testable import TuistApp

/// 세션 상태에 따라 항목 캐시를 비우는 분기와, 그 분기를 실제 Repository 에 잇는 조립을 고정한다.
@MainActor
@Suite("AppContainer 항목 캐시 비우기")
struct AppContainerItemCacheInvalidationTests {
    @Test("세션 상태 구독이 로그아웃 때 Repository 의 캐시를 비운다")
    func startClearingItemCache_signedOut_clearsRepositoryCache() async {
        let cache = InMemoryItemCache(records: [ItemCacheRecord(id: "9", title: "이전 계정 항목")])
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success([])),
            cache: cache,
            reporter: SpyDiagnosticReporter()
        )

        await AppContainer.startClearingItemCache(
            of: repository,
            whenSignedOutIn: StubAuthRepository(statuses: [.signedOut])
        ).value

        #expect(await cache.removeAllCount == 1)
    }

    @Test("로그인 상태가 아니게 되면 캐시를 비운다", arguments: [SessionStatus.signedOut, .expired])
    func clearItemCache_whenNotSignedIn_clearsOnce(status: SessionStatus) async {
        var clearCount = 0

        await AppContainer.clearItemCacheWhenSignedOut(statuses: Self.stream(of: [status])) {
            clearCount += 1
        }

        #expect(clearCount == 1)
    }

    @Test("로그인 상태면 캐시를 비우지 않는다")
    func clearItemCache_whenSignedIn_doesNotClear() async {
        var clearCount = 0

        await AppContainer.clearItemCacheWhenSignedOut(statuses: Self.stream(of: [.signedIn])) {
            clearCount += 1
        }

        #expect(clearCount == 0)
    }

    @Test("로그인했다가 로그아웃하면 로그아웃 때 한 번 비운다")
    func clearItemCache_signedInThenSignedOut_clearsOnce() async {
        var clearCount = 0

        await AppContainer.clearItemCacheWhenSignedOut(statuses: Self.stream(of: [.signedIn, .signedOut])) {
            clearCount += 1
        }

        #expect(clearCount == 1)
    }

    @Test("로그아웃 없이 다시 로그인하면 이전 계정의 캐시를 비운다")
    func clearItemCache_signedInAgain_clearsOnce() async {
        var clearCount = 0

        await AppContainer.clearItemCacheWhenSignedOut(statuses: Self.stream(of: [.signedIn, .signedIn])) {
            clearCount += 1
        }

        #expect(clearCount == 1)
    }

    @Test("로그아웃 상태에서 로그인하면 로그인 때도 비운다")
    func clearItemCache_signedOutThenSignedIn_clearsTwice() async {
        var clearCount = 0

        await AppContainer.clearItemCacheWhenSignedOut(statuses: Self.stream(of: [.signedOut, .signedIn])) {
            clearCount += 1
        }

        #expect(clearCount == 2)
    }

    /// `statuses` 를 차례로 보낸 뒤 끝나는 스트림.
    private static func stream(of statuses: [SessionStatus]) -> AsyncStream<SessionStatus> {
        let (stream, continuation) = AsyncStream<SessionStatus>.makeStream()
        for status in statuses {
            continuation.yield(status)
        }
        continuation.finish()
        return stream
    }
}
