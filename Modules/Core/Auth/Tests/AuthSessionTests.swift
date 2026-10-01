//
//  AuthSessionTests.swift
//  AuthTests
//

@testable import Auth
import AuthTesting
import Foundation
import Testing

@Suite("AuthSession")
struct AuthSessionTests {
    private let oldTokens = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh")
    private let newTokens = AuthTokens(accessToken: "new-access", refreshToken: "new-refresh")
    /// 갱신이 일어나지 않는 테스트의 refresh.
    private let unusedRefresh: AuthSession.Refresh = { _ in throw AuthenticationError.refreshFailed }

    /// 불변식("refresh 1회, 모두 새 토큰")만 검증한다. 게이트는 첫 호출이 refresh 에 들어간 것만 보장하므로,
    /// 나머지가 진행 중인 Task 에 합류했는지 "이미 갱신됨" 경로로 빠졌는지는 실행마다 다를 수 있다.
    /// 어느 경로든 refresh 가 두 번 불리면 실패한다.
    @Test("동시에 여러 번 호출해도 refresh 는 한 번만 하고 모두 새 토큰을 받는다")
    func refreshedAccessToken_concurrentCalls_refreshesOnce() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        let callCount = 5

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0 ..< callCount {
                group.addTask {
                    try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
                }
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
        let session = AuthSession(
            store: store,
            refresh: { _ in
                await counter.increment()
                return newTokens
            }
        )

        let token = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(token == newTokens.accessToken)
        #expect(await counter.value == 0)
    }

    @Test("갱신에 성공하면 새 토큰을 저장한다")
    func refreshedAccessToken_success_savesNewTokens() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let session = AuthSession(store: store, refresh: { _ in newTokens })

        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(await store.tokens == newTokens)
    }

    @Test("세션이 만료되면 토큰을 한 번 지우고 한 번 알린다")
    func refreshedAccessToken_sessionExpired_clearsStoreAndNotifiesOnce() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)
        let callCount = 3

        let failures = await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< callCount {
                group.addTask {
                    do {
                        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
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
        #expect(await states.next() == .expired)
        // 만료 알림이 한 번뿐이면 로그아웃 알림이 바로 뒤에 온다.
        try await session.signOut()
        #expect(await states.next() == .signedOut)
    }

    @Test("전송 실패는 토큰을 지우지 않고 에러를 전파한다")
    func refreshedAccessToken_transportFailure_keepsTokens() async {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let session = AuthSession(store: store, refresh: { _ in throw URLError(.notConnectedToInternet) })

        await #expect(throws: URLError.self) {
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        #expect(await store.clearCount == 0)
    }

    @Test("저장된 토큰이 없으면 세션 만료로 끝난다")
    func refreshedAccessToken_noStoredTokens_throwsSessionExpired() async {
        let session = AuthSession(store: InMemoryTokenStore(), refresh: { _ in newTokens })

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: session.rejecting(nil))
        }
    }

    @Test("갱신 뒤 저장에 실패해도 새 토큰을 돌려주고 다음 요청에도 쓴다")
    func refreshedAccessToken_saveFails_returnsNewToken() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let session = AuthSession(store: store, refresh: { _ in newTokens })

        let token = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(token == newTokens.accessToken)
        // 저장소에는 이전 토큰이 남아 있지만 다음 요청도 새 토큰을 쓴다.
        #expect(try await session.currentAccessToken().value == newTokens.accessToken)
    }

    @Test("저장에 실패한 뒤 다음 갱신에서 저장이 성공하면 저장소의 새 토큰을 쓴다")
    func refreshedAccessToken_saveSucceedsAfterFailure_usesStoredTokens() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let latestTokens = AuthTokens(accessToken: "latest-access", refreshToken: "latest-refresh")
        let sentRefreshTokens = ArgumentRecorder()
        let session = AuthSession(
            store: store,
            refresh: { [newTokens] refreshToken in
                // 첫 갱신은 저장에 실패하는 newTokens, 두 번째는 저장에 성공하는 latestTokens.
                await sentRefreshTokens.record(refreshToken) == 1 ? newTokens : latestTokens
            }
        )
        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        _ = try await session.refreshedAccessToken(rejected: session.rejecting(newTokens.accessToken))

        // 두 번째 갱신은 저장소의 이전 값이 아니라 메모리에 든 새 refresh token 으로 보낸다(D4).
        #expect(await sentRefreshTokens.values == [oldTokens.refreshToken, newTokens.refreshToken])
        #expect(await store.tokens == latestTokens)
        // 메모리에 들고 있던 newTokens 가 비워지지 않으면 여기서 newTokens 가 나온다.
        #expect(try await session.currentAccessToken().value == latestTokens.accessToken)
    }

    @Test("저장에 실패한 뒤 세션이 만료되면 메모리의 토큰도 비우고 다시 알리지 않는다")
    func refreshedAccessToken_sessionExpiresAfterSaveFailure_clearsUnsaved() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let counter = CallCounter()
        let session = AuthSession(
            store: store,
            refresh: { [newTokens] _ in
                if await counter.incrementAndGet() == 1 {
                    return newTokens
                }
                throw AuthenticationError.sessionExpired
            }
        )
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)
        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: session.rejecting(newTokens.accessToken))
        }
        #expect(try await session.currentAccessToken().value == nil)
        // 만료 뒤 늦게 도착한 401 은 만료를 다시 알리지 않는다(D3).
        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: session.rejecting(newTokens.accessToken))
        }
        try await session.signOut()
        #expect(await states.next() == .expired)
        #expect(await states.next() == .signedOut)
    }

    @Test("토큰 삭제에 실패해도 세션 만료를 알리고 sessionExpired 를 던진다")
    func refreshedAccessToken_clearFails_stillNotifiesSessionExpired() async {
        let store = FailingTokenStore(tokens: oldTokens, failsClear: true)
        let session = AuthSession(store: store, refresh: { _ in throw AuthenticationError.sessionExpired })
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        #expect(await states.next() == .expired)
    }

    @Test("실패한 뒤에도 다시 갱신할 수 있다")
    func refreshedAccessToken_afterFailure_canRefreshAgain() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let counter = CallCounter()
        let session = AuthSession(
            store: store,
            refresh: { _ in
                // 첫 호출만 실패시킨다.
                if await counter.incrementAndGet() == 1 {
                    throw URLError(.timedOut)
                }
                return newTokens
            }
        )
        _ = try? await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        let token = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(token == newTokens.accessToken)
    }
}

// MARK: - 로그인·로그아웃·상태

extension AuthSessionTests {
    @Test("로그인하면 토큰을 저장하고 signedIn 을 알린다")
    func signIn_saves_tokensAndEmitsSignedIn() async throws {
        let store = InMemoryTokenStore()
        let session = AuthSession(store: store, refresh: unusedRefresh)
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedOut)

        try await session.signIn(with: newTokens)

        #expect(await store.tokens == newTokens)
        #expect(await states.next() == .signedIn)
    }

    @Test("로그인 저장에 실패하면 던지고 상태를 알리지 않는다")
    func signIn_storeFails_throwsAndKeepsState() async throws {
        let session = AuthSession(store: FailingTokenStore(tokens: nil, saveFailures: 1), refresh: unusedRefresh)
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedOut)

        await #expect(throws: FailingTokenStore.Failure.self) {
            try await session.signIn(with: newTokens)
        }
        // 실패한 로그인이 signedIn 을 알렸다면 로그아웃보다 먼저 받는다.
        try await session.signOut()
        #expect(await states.next() == .signedOut)
    }

    @Test("저장하지 못한 갱신 토큰이 있어도 로그인한 토큰을 쓴다")
    func signIn_afterUnsaved_newTokensWin() async throws {
        let latestTokens = AuthTokens(accessToken: "latest-access", refreshToken: "latest-refresh")
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let session = AuthSession(store: store, refresh: { _ in newTokens })
        // 저장 실패 → 메모리에 보관
        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        try await session.signIn(with: latestTokens)

        #expect(try await session.currentAccessToken().value == latestTokens.accessToken)
    }

    @Test("로그아웃하면 토큰과 메모리의 토큰을 지우고 signedOut 을 알린다")
    func signOut_clearsAndEmitsSignedOut() async throws {
        let store = FailingTokenStore(tokens: oldTokens, saveFailures: 1)
        let session = AuthSession(store: store, refresh: { [newTokens] _ in newTokens })
        // 저장 실패 → 메모리에 보관
        _ = try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)

        try await session.signOut()

        #expect(await store.tokens == nil)
        #expect(try await session.currentAccessToken().value == nil)
        #expect(await states.next() == .signedOut)
    }

    @Test("로그아웃 삭제에 실패해도 signedOut 을 알리고 던진다")
    func signOut_storeFails_emitsSignedOutAndThrows() async throws {
        let session = AuthSession(store: FailingTokenStore(tokens: oldTokens, failsClear: true), refresh: unusedRefresh)
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)

        await #expect(throws: FailingTokenStore.Failure.self) {
            try await session.signOut()
        }
        #expect(await states.next() == .signedOut)
    }

    @Test("로그아웃 뒤에 끝난 갱신은 토큰을 되살리지 않고 기다리던 호출은 세션 만료로 끝난다")
    func refresh_finishesAfterSignOut_doesNotRestoreTokens() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await gate.waitUntilEntered()

        try await session.signOut()
        await gate.resume(with: .success(newTokens))

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await store.tokens == nil)
        #expect(try await session.currentAccessToken().value == nil)
    }

    @Test("로그인 뒤에 끝난 이전 세션의 갱신은 새 토큰을 덮어쓰지 않는다")
    func refresh_finishesAfterSignIn_keepsNewTokens() async throws {
        let latestTokens = AuthTokens(accessToken: "latest-access", refreshToken: "latest-refresh")
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await gate.waitUntilEntered()

        try await session.signIn(with: latestTokens)
        await gate.resume(with: .success(newTokens))

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await store.tokens == latestTokens)
        #expect(try await session.currentAccessToken().value == latestTokens.accessToken)
    }

    @Test("갱신 결과를 저장하는 중에 로그아웃해도 토큰이 남지 않는다")
    func refresh_saveInProgressDuringSignOut_doesNotRestoreTokens() async throws {
        let store = GatedSaveTokenStore(tokens: oldTokens)
        let session = AuthSession(store: store, refresh: { [newTokens] _ in newTokens })
        // 저장이 붙잡힌 동안에는 저장소를 읽을 수 없으므로 먼저 구독한다.
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await store.waitUntilSaveEntered()

        // 삭제는 진행 중인 저장 뒤에 실행되므로, 저장을 풀어 준 뒤에야 로그아웃이 끝난다.
        let signOut = Task { try await session.signOut() }
        #expect(await states.next() == .signedOut) // 로그아웃이 삭제를 요청한 뒤다.
        await store.resumeSave()
        try await signOut.value

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await store.tokens == nil)
    }

    @Test("로그인 저장 중에 로그아웃이 끼어들면 로그인은 취소되고 토큰이 남지 않는다")
    func signIn_signOutDuringSave_throwsCancellationAndClears() async throws {
        let store = GatedSaveTokenStore(tokens: nil)
        let session = AuthSession(store: store, refresh: unusedRefresh)
        // 저장이 붙잡힌 동안에는 저장소를 읽을 수 없으므로 먼저 구독한다.
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedOut)
        let signIn = Task { [newTokens] in try await session.signIn(with: newTokens) }
        await store.waitUntilSaveEntered()

        let signOut = Task { try await session.signOut() }
        #expect(await states.next() == .signedOut) // 로그아웃이 삭제를 요청한 뒤다.
        await store.resumeSave()
        try await signOut.value

        await #expect(throws: CancellationError.self) {
            try await signIn.value
        }
        #expect(await store.tokens == nil)
    }

    @Test("첫 값은 저장된 토큰이 있으면 signedIn, 없으면 signedOut 이다", arguments: [true, false])
    func states_firstValue_reflectsStoredTokens(hasStoredTokens: Bool) async {
        let session = AuthSession(
            store: InMemoryTokenStore(tokens: hasStoredTokens ? oldTokens : nil),
            refresh: unusedRefresh
        )
        var states = await session.states().makeAsyncIterator()

        #expect(await states.next() == (hasStoredTokens ? .signedIn : .signedOut))
    }

    @Test("여러 구독자가 모두 만료를 받는다")
    func states_multipleSubscribers_eachReceive() async {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let session = AuthSession(store: store, refresh: { _ in throw AuthenticationError.sessionExpired })
        var first = await session.states().makeAsyncIterator()
        var second = await session.states().makeAsyncIterator()
        _ = await first.next() // 현재 상태(.signedIn)
        _ = await second.next()

        _ = try? await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(await first.next() == .expired)
        #expect(await second.next() == .expired)
    }
}
