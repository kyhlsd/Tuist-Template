//
//  AppContainerItemCacheInvalidationTests.swift
//  TuistAppTests
//

import Domain
import Testing
@testable import TuistApp

/// 세션 상태에 따라 항목 캐시를 비우는 분기를 고정한다.
@MainActor
@Suite("AppContainer 항목 캐시 비우기")
struct AppContainerItemCacheInvalidationTests {
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
