//
//  AuthSessionTransitionRaceTests.swift
//  AuthTests
//

@testable import Auth
import AuthTesting
import Testing

/// 로그인·로그아웃·만료가 저장소 읽기나 갱신과 겹치는 경우. 겹치는 시점은 게이트와
/// `AuthSession` 의 테스트 동기화 지점으로 맞춘다(sleep 없음). 실패하면 멈출 수 있어 시간 제한을 둔다.
@Suite("AuthSession 전환 경쟁", .timeLimit(.minutes(1)))
struct AuthSessionTransitionRaceTests {
    private let oldTokens = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh")
    private let newTokens = AuthTokens(accessToken: "new-access", refreshToken: "new-refresh")
    private let latestTokens = AuthTokens(accessToken: "latest-access", refreshToken: "latest-refresh")
    private let unusedRefresh: AuthSession.Refresh = { _ in throw AuthenticationError.refreshFailed }

    // MARK: 저장소를 읽는 중의 전환 (R1-1)

    @Test("갱신할 토큰을 읽는 중에 로그아웃하면 갱신하지 않고 토큰이 남지 않는다")
    func refresh_signOutDuringLoad_doesNotRestoreTokens() async throws {
        let store = GatedLoadTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        await store.armLoadGate()
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await store.waitUntilLoadEntered()

        let signOut = Task { try await session.signOut() }
        // 로그아웃이 세대를 올린 뒤다. 삭제가 줄을 선 순서와 관계없이 결과는 같다.
        await session.waitUntilGeneration(atLeast: 1)
        await store.resumeLoad()
        try await signOut.value

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await gate.callCount == 0)
        #expect(await store.tokens == nil)
    }

    @Test("갱신할 토큰을 읽는 중에 로그인하면 갱신하지 않고 새 토큰이 남는다")
    func refresh_signInDuringLoad_keepsNewTokens() async throws {
        let store = GatedLoadTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        await store.armLoadGate()
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await store.waitUntilLoadEntered()

        let signIn = Task { [latestTokens] in try await session.signIn(with: latestTokens) }
        // 로그인이 세대를 올린 뒤다. 저장이 줄을 선 순서와 관계없이 결과는 같다.
        await session.waitUntilGeneration(atLeast: 1)
        await store.resumeLoad()
        try await signIn.value

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await gate.callCount == 0)
        #expect(await store.tokens == latestTokens)
    }

    // MARK: 이전 세션 갱신의 결과 (R1-3, R1-4)

    @Test("로그인 뒤에 이전 세션의 갱신이 거절돼도 새 세션을 만료시키지 않는다")
    func refresh_rejectedAfterSignIn_keepsNewSession() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        var states = await session.states().makeAsyncIterator()
        _ = await states.next() // 현재 상태(.signedIn)
        let pending = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await gate.waitUntilEntered()
        try await session.signIn(with: latestTokens)
        _ = await states.next() // 로그인(.signedIn)

        await gate.resume(with: .failure(AuthenticationError.sessionExpired))

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await pending.value
        }
        #expect(await store.tokens == latestTokens)
        #expect(await store.clearCount == 0)
        // 만료를 알렸다면 로그아웃보다 먼저 받는다.
        try await session.signOut()
        #expect(await states.next() == .signedOut)
    }

    @Test("이전 세션의 갱신을 기다리던 호출이 끝나도 새 세션의 갱신은 하나로 모인다")
    func refresh_staleWaiterFinishes_keepsNewRefreshInFlight() async throws {
        let refreshedTokens = AuthTokens(accessToken: "refreshed-access", refreshToken: "refreshed-refresh")
        let gate = RefreshGate()
        let session = AuthSession(store: InMemoryTokenStore(tokens: oldTokens), refresh: gate.refresh)
        let stale = Task { [oldTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))
        }
        await gate.waitUntilEntered(count: 1)
        try await session.signIn(with: latestTokens)
        let current = Task { [latestTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(latestTokens.accessToken))
        }
        await gate.waitUntilEntered(count: 2)

        await gate.resume(with: .success(newTokens)) // 이전 세션의 갱신을 끝낸다.
        _ = try? await stale.value
        // 이전 호출이 새 세션의 갱신을 떼어 냈다면 다음 401 이 같은 refresh token 으로 또 갱신한다.
        try #require(await session.isRefreshInFlight)
        let joining = Task { [latestTokens] in
            try await session.refreshedAccessToken(rejected: session.rejecting(latestTokens.accessToken))
        }
        await gate.resume(with: .success(refreshedTokens))

        #expect(try await current.value == refreshedTokens.accessToken)
        #expect(try await joining.value == refreshedTokens.accessToken)
        #expect(await gate.callCount == 2)
    }

    // MARK: 삭제 실패 뒤의 읽기 (R1-2)

    @Test("로그아웃 삭제에 실패해도 저장소에 남은 이전 토큰을 쓰지 않는다")
    func signOut_clearFails_doesNotUseStaleTokens() async throws {
        let session = AuthSession(store: FailingTokenStore(tokens: oldTokens, failsClear: true), refresh: unusedRefresh)
        _ = try? await session.signOut()

        #expect(try await session.currentAccessToken().value == nil)
        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: session.rejecting(nil))
        }
        #expect(await session.states().first { _ in true } == .signedOut)
    }

    @Test("만료 삭제에 실패해도 저장소에 남은 이전 토큰을 쓰지 않는다")
    func expire_clearFails_doesNotUseStaleTokens() async throws {
        let session = AuthSession(
            store: FailingTokenStore(tokens: oldTokens, failsClear: true),
            refresh: { _ in throw AuthenticationError.sessionExpired }
        )
        _ = try? await session.refreshedAccessToken(rejected: session.rejecting(oldTokens.accessToken))

        #expect(try await session.currentAccessToken().value == nil)
    }

    @Test("삭제에 실패한 뒤 로그인하면 새 토큰을 쓴다")
    func signIn_afterClearFailure_usesNewTokens() async throws {
        let session = AuthSession(store: FailingTokenStore(tokens: oldTokens, failsClear: true), refresh: unusedRefresh)
        _ = try? await session.signOut()

        try await session.signIn(with: latestTokens)

        #expect(try await session.currentAccessToken().value == latestTokens.accessToken)
    }

    @Test("로그아웃 삭제가 끝나기 전의 읽기도 이전 토큰을 쓰지 않는다")
    func signOut_readDuringFailingClear_doesNotUseStaleTokens() async throws {
        let store = GatedClearTokenStore(tokens: oldTokens)
        let session = AuthSession(store: store, refresh: unusedRefresh)
        let signOut = Task { try await session.signOut() }
        await store.waitUntilClearEntered()

        // 저장소를 읽으려 하면 붙잡힌 삭제 뒤로 줄을 서서 여기서 멈춘다(시간 제한).
        #expect(try await session.currentAccessToken().value == nil)
        await store.failClear()
        await #expect(throws: FailingTokenStore.Failure.self) {
            try await signOut.value
        }
        #expect(try await session.currentAccessToken().value == nil)
    }

    @Test("로그아웃 삭제와 함께 진행한 로그인의 저장도 실패하면 이전 토큰을 쓰지 않는다")
    func signIn_saveFailsDuringFailingClear_doesNotUseStaleTokens() async throws {
        let store = GatedClearTokenStore(tokens: oldTokens, failsSave: true)
        let session = AuthSession(store: store, refresh: unusedRefresh)
        let signOut = Task { try await session.signOut() }
        await store.waitUntilClearEntered()
        let signIn = Task { [latestTokens] in try await session.signIn(with: latestTokens) }
        // 로그인이 세대를 올린 뒤다. 저장이 줄을 선 순서와 관계없이 결과는 같다.
        await session.waitUntilGeneration(atLeast: 2)

        await store.failClear()
        _ = try? await signOut.value
        await #expect(throws: FailingTokenStore.Failure.self) {
            try await signIn.value
        }

        #expect(try await session.currentAccessToken().value == nil)
    }

    // MARK: 구독 정리 (R1-9)

    @Test("구독을 취소하면 AuthSession 의 구독이 정리된다")
    func states_subscriberCancelled_removesSubscription() async {
        let session = AuthSession(store: InMemoryTokenStore(), refresh: unusedRefresh)
        let stream = await session.states()
        let consumer = Task {
            for await _ in stream {}
        }

        consumer.cancel()
        await consumer.value

        // 정리되지 않으면 여기서 끝나지 않아 시간 제한에 걸린다.
        await session.waitUntilNoSubscribers()
    }

    // MARK: 요청을 보낸 뒤의 전환 (리뷰 템플릿 R1-3)

    @Test("토큰을 읽은 뒤 다른 계정으로 로그인하면 그 토큰의 401 은 새 토큰을 돌려주지 않고 세션 만료로 끝난다")
    func refresh_signedInAgainAfterRead_throwsSessionExpiredWithoutNewToken() async throws {
        let gate = RefreshGate()
        let session = AuthSession(store: InMemoryTokenStore(tokens: oldTokens), refresh: gate.refresh)
        let rejected = try await session.currentAccessToken()

        try await session.signOut()
        try await session.signIn(with: latestTokens)

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: rejected)
        }
        #expect(await gate.callCount == 0)
        #expect(try await session.currentAccessToken().value == latestTokens.accessToken)
    }

    @Test("토큰을 읽는 중에 다른 계정으로 로그인하면 읽은 토큰의 401 은 새 토큰을 돌려주지 않는다")
    func refresh_signedInDuringRead_throwsSessionExpiredWithoutNewToken() async throws {
        let store = GatedLoadTokenStore(tokens: oldTokens)
        let gate = RefreshGate()
        let session = AuthSession(store: store, refresh: gate.refresh)
        await store.armLoadGate()
        let read = Task { try await session.currentAccessToken() }
        await store.waitUntilLoadEntered()

        let signIn = Task { [latestTokens] in try await session.signIn(with: latestTokens) }
        // 로그인이 세대를 올린 뒤에 읽기를 끝낸다. 읽기가 먼저 줄을 섰으므로 이전 계정 토큰을 받는다.
        await session.waitUntilGeneration(atLeast: 1)
        await store.resumeLoad()
        try await signIn.value
        let rejected = try await read.value

        #expect(rejected.value == oldTokens.accessToken)
        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: rejected)
        }
        #expect(await gate.callCount == 0)
    }

    @Test("로그인 전에 읽은 값의 401 은 그 뒤 로그인했어도 새 토큰을 돌려주지 않는다")
    func refresh_signedInAfterSignedOutRead_throwsSessionExpired() async throws {
        let session = AuthSession(store: InMemoryTokenStore(), refresh: unusedRefresh)
        let rejected = try await session.currentAccessToken()

        try await session.signIn(with: latestTokens)

        await #expect(throws: AuthenticationError.sessionExpired) {
            try await session.refreshedAccessToken(rejected: rejected)
        }
    }
}
