//
//  TokenRefresherTests.swift
//  NetworkingTests
//

import Foundation
@testable import Networking
import NetworkingTesting
import Testing

@Suite("TokenRefresher")
struct TokenRefresherTests {
    private let oldTokens = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh")
    private let newTokens = AuthTokens(accessToken: "new-access", refreshToken: "new-refresh")

    /// 불변식("refresh 1회, 모두 새 토큰")만 검증한다. 게이트는 첫 호출이 refresh 에 들어간 것만 보장하므로,
    /// 나머지가 진행 중인 Task 에 합류했는지 "이미 갱신됨" 경로로 빠졌는지는 실행마다 다를 수 있다.
    /// 어느 경로든 refresh 가 두 번 불리면 실패한다.
    @Test("동시에 여러 번 호출해도 refresh 는 한 번만 하고 모두 새 토큰을 받는다")
    func refreshedAccessToken_concurrentCalls_refreshesOnce() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let refresher = TokenRefresher(store: store, refresh: gate.refresh, onSessionExpired: {})
        let callCount = 5

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0 ..< callCount {
                group.addTask { try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken) }
            }
            // 첫 호출이 refresh 에 들어간 뒤에 풀어 준다.
            await gate.waitUntilEntered()
            await gate.resume(with: .success(newTokens))
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }

        #expect(await gate.callCount == 1)
        #expect(tokens == Array(repeating: newTokens.accessToken, count: callCount))
    }

    @Test("거절된 토큰이 이미 바뀌었으면 refresh 없이 현재 토큰을 돌려준다")
    func refreshedAccessToken_rejectedTokenIsStale_returnsCurrentWithoutRefresh() async throws {
        let store = InMemoryTokenStore(tokens: newTokens)
        let counter = CallCounter()
        let refresher = TokenRefresher(
            store: store,
            refresh: { _ in
                await counter.increment()
                return newTokens
            },
            onSessionExpired: {}
        )

        let token = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        #expect(token == newTokens.accessToken)
        #expect(await counter.value == 0)
    }

    @Test("갱신에 성공하면 새 토큰을 저장한다")
    func refreshedAccessToken_success_savesNewTokens() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let refresher = TokenRefresher(store: store, refresh: { _ in newTokens }, onSessionExpired: {})

        _ = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        #expect(await store.tokens == newTokens)
    }

    @Test("세션이 만료되면 토큰을 한 번 지우고 한 번 알린다")
    func refreshedAccessToken_sessionExpired_clearsStoreAndNotifiesOnce() async {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let expiredCount = CallCounter()
        let refresher = TokenRefresher(
            store: store,
            refresh: gate.refresh,
            onSessionExpired: { await expiredCount.increment() }
        )
        let callCount = 3

        let failures = await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< callCount {
                group.addTask {
                    do {
                        _ = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)
                        return false
                    } catch {
                        return error as? AuthenticationError == .sessionExpired
                    }
                }
            }
            await gate.waitUntilEntered()
            await gate.resume(with: .failure(AuthenticationError.sessionExpired))
            return await group.reduce(into: 0) { $0 += $1 ? 1 : 0 }
        }

        #expect(failures == callCount)
        #expect(await store.clearCount == 1)
        #expect(await expiredCount.value == 1)
    }

    @Test("전송 실패는 토큰을 지우지 않고 에러를 전파한다")
    func refreshedAccessToken_transportFailure_keepsTokens() async {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let refresher = TokenRefresher(
            store: store,
            refresh: { _ in throw URLError(.notConnectedToInternet) },
            onSessionExpired: {}
        )

        await #expect(throws: URLError.self) {
            try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)
        }
        #expect(await store.clearCount == 0)
    }

    @Test("저장된 토큰이 없으면 세션 만료로 끝난다")
    func refreshedAccessToken_noStoredTokens_throwsSessionExpired() async {
        let refresher = TokenRefresher(
            store: InMemoryTokenStore(),
            refresh: { _ in newTokens },
            onSessionExpired: {}
        )

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await refresher.refreshedAccessToken(rejected: nil)
        }
    }

    @Test("갱신 뒤 저장에 실패해도 새 토큰을 돌려주고 다음 요청에도 쓴다")
    func refreshedAccessToken_saveFails_returnsNewToken() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let refresher = TokenRefresher(store: store, refresh: { _ in newTokens }, onSessionExpired: {})

        let token = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        #expect(token == newTokens.accessToken)
        // 저장소에는 이전 토큰이 남아 있지만 다음 요청도 새 토큰을 쓴다.
        #expect(try await refresher.currentAccessToken() == newTokens.accessToken)
    }

    @Test("저장에 실패한 뒤 다음 갱신에서 저장이 성공하면 저장소의 새 토큰을 쓴다")
    func refreshedAccessToken_saveSucceedsAfterFailure_usesStoredTokens() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let latestTokens = AuthTokens(accessToken: "latest-access", refreshToken: "latest-refresh")
        let sentRefreshTokens = ArgumentRecorder()
        let refresher = TokenRefresher(
            store: store,
            refresh: { [newTokens] refreshToken in
                // 첫 갱신은 저장에 실패하는 newTokens, 두 번째는 저장에 성공하는 latestTokens.
                await sentRefreshTokens.record(refreshToken) == 1 ? newTokens : latestTokens
            },
            onSessionExpired: {}
        )
        _ = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        _ = try await refresher.refreshedAccessToken(rejected: newTokens.accessToken)

        // 두 번째 갱신은 저장소의 이전 값이 아니라 메모리에 든 새 refresh token 으로 보낸다(D4).
        #expect(await sentRefreshTokens.values == [oldTokens.refreshToken, newTokens.refreshToken])
        #expect(await store.tokens == latestTokens)
        // 메모리에 들고 있던 newTokens 가 비워지지 않으면 여기서 newTokens 가 나온다.
        #expect(try await refresher.currentAccessToken() == latestTokens.accessToken)
    }

    @Test("저장에 실패한 뒤 세션이 만료되면 메모리의 토큰도 비우고 다시 알리지 않는다")
    func refreshedAccessToken_sessionExpiresAfterSaveFailure_clearsUnsaved() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let counter = CallCounter()
        let expiredCount = CallCounter()
        let refresher = TokenRefresher(
            store: store,
            refresh: { [newTokens] _ in
                if await counter.incrementAndGet() == 1 {
                    return newTokens
                }
                throw AuthenticationError.sessionExpired
            },
            onSessionExpired: { await expiredCount.increment() }
        )
        _ = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await refresher.refreshedAccessToken(rejected: newTokens.accessToken)
        }
        #expect(try await refresher.currentAccessToken() == nil)
        // 만료 뒤 늦게 도착한 401 은 콜백을 다시 부르지 않는다(D3).
        await #expect(throws: AuthenticationError.sessionExpired) {
            try await refresher.refreshedAccessToken(rejected: newTokens.accessToken)
        }
        #expect(await expiredCount.value == 1)
    }

    @Test("토큰 삭제에 실패해도 세션 만료를 알리고 sessionExpired 를 던진다")
    func refreshedAccessToken_clearFails_stillNotifiesSessionExpired() async {
        let store = FailingTokenStore(tokens: oldTokens, failsClear: true)
        let expiredCount = CallCounter()
        let refresher = TokenRefresher(
            store: store,
            refresh: { _ in throw AuthenticationError.sessionExpired },
            onSessionExpired: { await expiredCount.increment() }
        )

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)
        }
        #expect(await expiredCount.value == 1)
    }

    @Test("실패한 뒤에도 다시 갱신할 수 있다")
    func refreshedAccessToken_afterFailure_canRefreshAgain() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let counter = CallCounter()
        let refresher = TokenRefresher(
            store: store,
            refresh: { _ in
                // 첫 호출만 실패시킨다.
                if await counter.incrementAndGet() == 1 {
                    throw URLError(.timedOut)
                }
                return newTokens
            },
            onSessionExpired: {}
        )
        _ = try? await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        let token = try await refresher.refreshedAccessToken(rejected: oldTokens.accessToken)

        #expect(token == newTokens.accessToken)
    }
}

/// 호출 횟수를 센다.
private actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }

    func incrementAndGet() -> Int {
        value += 1
        return value
    }
}

/// refresh 클로저가 받은 인자를 순서대로 기록한다.
private actor ArgumentRecorder {
    private(set) var values: [String] = []

    /// 기록하고 지금까지의 호출 횟수를 돌려준다.
    func record(_ value: String) -> Int {
        values.append(value)
        return values.count
    }
}

/// 저장·삭제를 실패시킬 수 있는 `TokenStore`. 저장은 처음 `saveFailures` 번만 실패한다.
private actor FailingTokenStore: TokenStore {
    private(set) var tokens: AuthTokens?
    private var saveFailures: Int
    private let failsClear: Bool

    init(tokens: AuthTokens?, saveFailures: Int = 0, failsClear: Bool = false) {
        self.tokens = tokens
        self.saveFailures = saveFailures
        self.failsClear = failsClear
    }

    func load() async throws -> AuthTokens? {
        tokens
    }

    func save(_ tokens: AuthTokens) async throws {
        if saveFailures > 0 {
            saveFailures -= 1
            throw StoreFailure()
        }
        self.tokens = tokens
    }

    func clear() async throws {
        if failsClear {
            throw StoreFailure()
        }
        tokens = nil
    }
}

private struct StoreFailure: Error {}

/// refresh 호출을 붙잡아 두었다가 테스트가 원할 때 결과를 넘겨준다. sleep 없이 동시 호출을 겹치게 한다.
private actor RefreshGate {
    private(set) var callCount = 0
    private var pending: CheckedContinuation<AuthTokens, any Error>?
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    nonisolated var refresh: TokenRefresher.Refresh {
        { _ in try await self.enter() }
    }

    func waitUntilEntered() async {
        if pending != nil {
            return
        }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func resume(with result: Result<AuthTokens, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }

    private func enter() async throws -> AuthTokens {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            enteredWaiters.forEach { $0.resume() }
            enteredWaiters.removeAll()
        }
    }
}
