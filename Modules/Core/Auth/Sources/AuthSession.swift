//
//  AuthSession.swift
//  Auth
//

import os

/// 로그인 세션의 토큰을 읽고, 갱신하고, 로그인·로그아웃으로 바꾼다.
///
/// Networking 의 인증 미들웨어가 토큰을 읽고 401 갱신을 맡기며, Data 의 Repository 가 로그인·로그아웃을 부른다.
/// refresh 호출 자체는 `Refresh` 로 주입받아 명세·생성 클라이언트를 모른다.
///
/// 진행 중인 갱신이 있으면 새 호출은 그 `Task` 를 기다린다. actor 는 `await` 지점에서
/// 재진입할 수 있으므로, `inFlight`·세대 확인과 그에 따른 상태 변경은 항상 `await` 없이 이어서 한다.
///
/// 세대(`generation`): 로그인·로그아웃·만료마다 올린다. 갱신 `Task` 는 시작한 세대가 끝날 때까지 그대로일 때만
/// 결과를 저장한다. 이전 세션의 갱신이 로그아웃 뒤 토큰을 되살리거나 새 로그인 토큰을 덮어쓰지 않게 한다.
///
/// 저장소 접근은 이 actor 가 요청한 순서대로 하나씩 한다(`serialized`). 갱신 결과 저장이 진행 중일 때
/// 로그아웃하면 삭제가 그 저장 뒤에 실행되어 이전 토큰이 남지 않는다.
public actor AuthSession: AccessTokenProviding, SessionManaging {
    public typealias Refresh = @Sendable (_ refreshToken: String) async throws -> AuthTokens

    private let store: any TokenStore
    private let refresh: Refresh
    private let logger: Logger
    private var inFlight: Task<AuthTokens, any Error>?
    /// 저장에 실패한 새 토큰. 저장소에는 이전 토큰이 남아 있으므로 저장이 성공하거나 세션이 바뀔 때까지
    /// 저장소보다 먼저 읽는다. 앱을 다시 시작하면 사라진다.
    ///
    /// 값이 있는 동안에는 저장소를 읽지 않는다. 그래서 세션을 바꾸는 모든 경로(로그인·로그아웃·만료)는
    /// 이 타입을 거치고 `unsaved` 를 비운다. 저장소에 직접 쓰면 새 토큰이 가려진다.
    private var unsaved: AuthTokens?
    /// 로그아웃·만료가 시작되면 삭제 결과와 관계없이 켠다. 켜져 있는 동안 저장소를 읽지 않는다.
    /// 삭제가 끝나기 전이나 실패한 뒤에 남은 이전 토큰을 읽지 않기 위해서다. 로그인에 성공하면 끈다.
    /// 앱을 다시 시작하면 사라진다(확정 결정 기록 D8 참고).
    private var storeDiscarded = false
    private var generation = 0
    /// 마지막 저장소 접근. 다음 접근은 이것이 끝난 뒤에 시작한다.
    private var lastStoreOperation: Task<Void, Never>?
    /// 마지막으로 방송한 상태. 아직 없으면 저장소의 토큰으로 판단한다.
    private var state: State?
    private var subscribers: [Int: AsyncStream<State>.Continuation] = [:]
    private var nextSubscriberID = 0
    /// 테스트 동기화 지점의 대기자. 이 파일 아래의 `테스트 동기화 지점` 확장 참고.
    private var generationWaiters: [(generation: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var noSubscriberWaiters: [CheckedContinuation<Void, Never>] = []

    /// - Parameters:
    ///   - refresh: refresh token 으로 새 토큰을 받아 온다. 서버가 거절하면
    ///     `AuthenticationError.sessionExpired` 를 던진다.
    ///   - logger: 세션 만료와 저장소 실패(갱신·로그인·로그아웃)를 남긴다. 기본값은 아무것도 남기지 않는다.
    public init(
        store: any TokenStore,
        refresh: @escaping Refresh,
        logger: Logger = Logger(.disabled)
    ) {
        self.store = store
        self.refresh = refresh
        self.logger = logger
    }

    public func currentAccessToken() async throws -> SessionToken {
        // 세대는 읽기 전에 잡는다. 읽는 동안 세션이 바뀌면 이 토큰의 401 은 갱신하지 않는다.
        let readGeneration = generation
        return try await SessionToken(value: loadTokens()?.accessToken, generation: readGeneration)
    }

    /// 새 access token 을 돌려준다.
    ///
    /// - Parameter rejected: 401 을 받은 요청이 `currentAccessToken()` 에서 받은 값. 저장소의 토큰이 이미
    ///   이것과 다르면 다른 호출이 갱신을 끝낸 것이므로 네트워크 호출 없이 현재 토큰을 쓴다.
    /// - Throws: 요청을 보낸 뒤나 저장소를 읽거나 갱신하는 중에 로그인·로그아웃으로 세션이 바뀌었으면
    ///   `AuthenticationError.sessionExpired`. 이전 세션의 요청을 새 토큰으로 다시 보내지 않는다.
    public func refreshedAccessToken(rejected: SessionToken) async throws -> String {
        // 요청이 토큰을 읽은 뒤 세션이 바뀌었으면 401 은 이전 세션의 것이다. 진행 중인 갱신도 새 세션의 것이다.
        guard rejected.generation == generation else {
            throw AuthenticationError.sessionExpired
        }
        if let inFlight {
            return try await inFlight.value.accessToken
        }

        // 세대는 읽기 전에 잡는다. 읽는 동안 세션이 바뀌면 읽은 토큰은 이전 세션의 것이다.
        let startGeneration = generation
        // 토큰이 없으면 로그인 전이거나 만료 처리가 이미 끝난 상태다. 지울 것도 없고,
        // 만료 뒤 늦게 도착한 401 이 만료를 다시 알리면 안 되므로 에러만 던진다.
        guard let current = try await loadTokens() else {
            throw AuthenticationError.sessionExpired
        }
        guard generation == startGeneration else {
            throw AuthenticationError.sessionExpired
        }
        if current.accessToken != rejected.value {
            return current.accessToken
        }

        // 저장소를 읽는 동안 다른 호출이 갱신을 시작했을 수 있다.
        if let inFlight {
            return try await inFlight.value.accessToken
        }

        let task = makeRefreshTask(refreshToken: current.refreshToken, generation: startGeneration)
        inFlight = task
        // 기다리는 동안 로그인·로그아웃이 `inFlight` 를 비우고 새 갱신이 들어왔을 수 있다. 그 갱신은 지우지 않는다.
        defer {
            if inFlight == task {
                inFlight = nil
            }
        }
        return try await task.value.accessToken
    }

    /// 로그인으로 받은 토큰을 저장하고 `.signedIn` 을 알린다.
    ///
    /// 진행 중인 갱신은 이전 세션의 것이 되어 결과를 버린다.
    /// - Throws: 저장 실패. 상태는 알리지 않는다. 이전 토큰을 무효로 만든 것이 아니므로 다시 시도하면 된다.
    ///   저장하는 동안 로그아웃 등 다른 전환이 먼저 끝났으면 `CancellationError`. 그 전환의 결과가 남는다.
    public func signIn(with tokens: AuthTokens) async throws {
        let signInGeneration = startNewGeneration()
        do {
            try await serialized { try await $0.save(tokens) }
        } catch {
            logger.error("로그인 토큰 저장 실패: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
        // 저장하는 동안 세션이 또 바뀌었으면 그쪽이 최신이다. 뒤따른 삭제·저장이 저장소도 그쪽으로 맞춘다.
        guard generation == signInGeneration else {
            throw CancellationError()
        }
        unsaved = nil
        storeDiscarded = false
        broadcast(.signedIn)
    }

    /// 저장된 토큰을 지우고 `.signedOut` 을 알린다. 서버 호출은 없다.
    ///
    /// - Throws: 삭제 실패. 메모리의 토큰은 이미 비웠고 `.signedOut` 도 알린 뒤다.
    ///   저장소에 남은 토큰은 이 프로세스에서 다시 읽지 않고, 다음 로그인 때 덮인다.
    public func signOut() async throws {
        startNewGeneration()
        unsaved = nil
        storeDiscarded = true
        // 삭제를 기다리는 동안 다른 전환이 먼저 알리면 순서가 뒤집히므로, 알림은 기다리기 전에 한다.
        broadcast(.signedOut)
        do {
            try await serialized { try await $0.clear() }
        } catch {
            logger.error("로그아웃 토큰 삭제 실패: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
    }

    /// 세션 상태 스트림. 첫 값은 현재 상태이고, 이후 로그인·로그아웃·만료 때마다 값이 온다.
    ///
    /// 구독마다 따로 스트림을 만든다. 여러 곳이 동시에 구독해도 모두 같은 값을 받는다.
    /// 현재 상태를 처음 판단할 때 저장소를 읽지 못하면 `.signedOut` 으로 본다.
    public func states() async -> AsyncStream<State> {
        let initial = await currentState()
        let (stream, continuation) = AsyncStream<State>.makeStream()
        let id = nextSubscriberID
        nextSubscriberID += 1
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else {
                return
            }
            Task { await self.removeSubscriber(id) }
        }
        continuation.yield(initial)
        return stream
    }

    /// - Parameter startGeneration: 갱신할 토큰을 읽기 전에 잡은 세대.
    private func makeRefreshTask(refreshToken: String, generation startGeneration: Int) -> Task<AuthTokens, any Error> {
        Task {
            let tokens: AuthTokens
            do {
                tokens = try await refresh(refreshToken)
            } catch AuthenticationError.sessionExpired {
                // 같은 Task 를 기다리는 호출자들은 에러만 받는다. 정리와 알림은 여기서 한 번만 한다.
                // 그사이 세션이 바뀌었으면 거절된 것은 이전 세션이므로 새 세션을 건드리지 않는다.
                if generation == startGeneration {
                    await expireSession()
                }
                throw AuthenticationError.sessionExpired
            }

            // 기다리는 동안 로그인·로그아웃·만료가 있었으면 이 결과는 이전 세션의 것이다.
            guard generation == startGeneration else {
                throw AuthenticationError.sessionExpired
            }
            let saveError: (any Error)?
            do {
                try await serialized { try await $0.save(tokens) }
                saveError = nil
            } catch {
                saveError = error
            }
            // 저장하는 동안 세션이 바뀌었으면 뒤따른 삭제·저장이 저장소를 이미 새 세션으로 맞췄다.
            guard generation == startGeneration else {
                throw AuthenticationError.sessionExpired
            }
            if let saveError {
                // 서버가 refresh token 을 교체했다면 이전 토큰은 이미 무효다. 저장에 실패했다고 새 토큰까지
                // 버리면 다음 갱신에서 세션이 끝나므로, 메모리에 들고 있으면서 실패는 로그로 남긴다.
                unsaved = tokens
                logger.error("토큰 저장 실패: \(String(describing: type(of: saveError)), privacy: .public)")
            } else {
                unsaved = nil
            }
            return tokens
        }
    }

    private func loadTokens() async throws -> AuthTokens? {
        if let unsaved {
            return unsaved
        }
        if storeDiscarded {
            return nil
        }
        return try await serialized { try await $0.load() }
    }

    /// 토큰을 지우고 만료를 알린다.
    ///
    /// 삭제에 실패해도 서버는 이미 세션을 거절했으므로 만료는 알린다. 남은 토큰은 이 프로세스에서 다시 읽지 않는다.
    /// 앱을 다시 시작하면 남은 토큰을 읽지만, 서버가 다시 거절해 만료 처리와 삭제가 재시도된다.
    private func expireSession() async {
        startNewGeneration()
        unsaved = nil
        storeDiscarded = true
        broadcast(.expired)
        logger.notice("세션이 만료되어 저장된 토큰을 지웁니다.")
        do {
            try await serialized { try await $0.clear() }
        } catch {
            logger.error("토큰 삭제 실패: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// 세대를 올리고 진행 중인 갱신을 떼어 낸다. 떼어 낸 갱신은 끝나도 결과를 저장하지 않는다.
    @discardableResult
    private func startNewGeneration() -> Int {
        generation += 1
        inFlight = nil
        resumeGenerationWaiters()
        return generation
    }

    /// 저장소 접근을 요청한 순서대로 하나씩 실행한다.
    ///
    /// 순서는 호출한 시점(첫 `await` 전)에 정해진다. 앞선 접근이 실패해도 다음 접근은 실행한다.
    private func serialized<Value: Sendable>(
        _ operation: @escaping @Sendable (any TokenStore) async throws -> Value
    ) async throws -> Value {
        let previous = lastStoreOperation
        let store = store
        let task = Task<Value, any Error> {
            _ = await previous?.result
            return try await operation(store)
        }
        lastStoreOperation = Task { _ = await task.result }
        return try await task.value
    }

    private func currentState() async -> State {
        if let state {
            return state
        }
        let stored: State
        do {
            stored = try await loadTokens() == nil ? .signedOut : .signedIn
        } catch {
            logger.error("세션 상태 판단 중 토큰 읽기 실패: \(String(describing: type(of: error)), privacy: .public)")
            stored = .signedOut
        }
        // 읽는 동안 로그인·로그아웃·만료가 있었으면 그쪽이 최신이다.
        return state ?? stored
    }

    private func broadcast(_ newState: State) {
        state = newState
        for continuation in subscribers.values {
            continuation.yield(newState)
        }
    }

    private func removeSubscriber(_ id: Int) {
        subscribers[id] = nil
        if subscribers.isEmpty {
            noSubscriberWaiters.forEach { $0.resume() }
            noSubscriberWaiters.removeAll()
        }
    }

    private func resumeGenerationWaiters() {
        let ready = generationWaiters.filter { $0.generation <= generation }
        generationWaiters.removeAll { $0.generation <= generation }
        ready.forEach { $0.continuation.resume() }
    }
}

// MARK: - 테스트 동기화 지점

/// `@testable import` 하는 테스트만 쓴다. sleep 없이 actor 안의 전환 시점을 기다리기 위한 것이다.
extension AuthSession {
    /// 지금 세대에서 `value` 를 붙여 보낸 요청이 401 을 받은 것으로 본다.
    func rejecting(_ value: String?) -> SessionToken {
        SessionToken(value: value, generation: generation)
    }

    /// 진행 중인 갱신이 있는지.
    var isRefreshInFlight: Bool {
        inFlight != nil
    }

    /// 로그인·로그아웃·만료로 세대가 `target` 이상이 될 때까지 기다린다.
    func waitUntilGeneration(atLeast target: Int) async {
        if generation >= target {
            return
        }
        await withCheckedContinuation { generationWaiters.append((target, $0)) }
    }

    /// 상태 구독이 모두 정리될 때까지 기다린다.
    func waitUntilNoSubscribers() async {
        if subscribers.isEmpty {
            return
        }
        await withCheckedContinuation { noSubscriberWaiters.append($0) }
    }
}
