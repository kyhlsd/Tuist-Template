//
//  AuthSessionTestDoubles.swift
//  AuthTests
//

import Auth
import AuthTesting

// 이 테스트 타깃(AuthTests)이 쓰는 테스트 더블. 타깃 밖에서는 쓰지 않으므로 AuthTesting 으로 빼지 않는다.

/// 호출 횟수를 센다.
actor CallCounter {
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
actor ArgumentRecorder {
    private(set) var values: [String] = []

    /// 기록하고 지금까지의 호출 횟수를 돌려준다.
    func record(_ value: String) -> Int {
        values.append(value)
        return values.count
    }
}

/// 저장을 붙잡아 두었다가 테스트가 원할 때 끝내는 `TokenStore`. 저장 중에 다른 전환을 끼워 넣는다.
actor GatedSaveTokenStore: TokenStore {
    private(set) var tokens: AuthTokens?
    private var pendingSave: CheckedContinuation<Void, Never>?
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    init(tokens: AuthTokens?) {
        self.tokens = tokens
    }

    func load() async throws -> AuthTokens? {
        tokens
    }

    func save(_ tokens: AuthTokens) async throws {
        await withCheckedContinuation { continuation in
            pendingSave = continuation
            enteredWaiters.forEach { $0.resume() }
            enteredWaiters.removeAll()
        }
        self.tokens = tokens
    }

    func clear() async throws {
        tokens = nil
    }

    func waitUntilSaveEntered() async {
        if pendingSave != nil {
            return
        }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func resumeSave() {
        pendingSave?.resume()
        pendingSave = nil
    }
}

/// refresh 호출을 붙잡아 두었다가 테스트가 원할 때 결과를 넘겨준다. sleep 없이 동시 호출을 겹치게 한다.
actor RefreshGate {
    private(set) var callCount = 0
    /// 들어온 순서대로 붙잡힌 refresh 호출.
    private var pending: [CheckedContinuation<AuthTokens, any Error>] = []
    private var enteredWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    nonisolated var refresh: AuthSession.Refresh {
        { _ in try await self.enter() }
    }

    /// refresh 가 모두 `count` 번 불릴 때까지 기다린다.
    func waitUntilEntered(count: Int = 1) async {
        if callCount >= count {
            return
        }
        await withCheckedContinuation { enteredWaiters.append((count, $0)) }
    }

    /// 붙잡힌 호출 중 가장 먼저 들어온 것을 끝낸다.
    func resume(with result: Result<AuthTokens, any Error>) {
        guard !pending.isEmpty else {
            return
        }
        pending.removeFirst().resume(with: result)
    }

    private func enter() async throws -> AuthTokens {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            let ready = enteredWaiters.filter { $0.count <= callCount }
            enteredWaiters.removeAll { $0.count <= callCount }
            ready.forEach { $0.continuation.resume() }
        }
    }
}

/// `load` 를 붙잡아 두었다가 테스트가 원할 때 끝내는 `TokenStore`. 저장소를 읽는 중에 다른 전환을 끼워 넣는다.
///
/// `armLoadGate()` 를 부른 뒤의 첫 `load` 만 붙잡는다. 그 전 읽기(구독의 첫 상태 등)는 바로 끝난다.
actor GatedLoadTokenStore: TokenStore {
    private(set) var tokens: AuthTokens?
    private(set) var clearCount = 0
    private var isArmed = false
    private var pendingLoad: CheckedContinuation<Void, Never>?
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    init(tokens: AuthTokens?) {
        self.tokens = tokens
    }

    func armLoadGate() {
        isArmed = true
    }

    func load() async throws -> AuthTokens? {
        if isArmed {
            isArmed = false
            await withCheckedContinuation { continuation in
                pendingLoad = continuation
                enteredWaiters.forEach { $0.resume() }
                enteredWaiters.removeAll()
            }
        }
        return tokens
    }

    func save(_ tokens: AuthTokens) async throws {
        self.tokens = tokens
    }

    func clear() async throws {
        tokens = nil
        clearCount += 1
    }

    func waitUntilLoadEntered() async {
        if pendingLoad != nil {
            return
        }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func resumeLoad() {
        pendingLoad?.resume()
        pendingLoad = nil
    }
}

/// `clear` 를 붙잡아 두었다가 테스트가 원할 때 실패로 끝내는 `TokenStore`. 삭제 중의 읽기·로그인을 끼워 넣는다.
///
/// `failsSave` 면 저장도 실패한다(Keychain 잠김처럼 실패가 함께 오는 경우).
actor GatedClearTokenStore: TokenStore {
    private(set) var tokens: AuthTokens?
    private let failsSave: Bool
    private var pendingClear: CheckedContinuation<Void, Never>?
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    init(tokens: AuthTokens?, failsSave: Bool = false) {
        self.tokens = tokens
        self.failsSave = failsSave
    }

    func load() async throws -> AuthTokens? {
        tokens
    }

    func save(_ tokens: AuthTokens) async throws {
        if failsSave {
            throw FailingTokenStore.Failure()
        }
        self.tokens = tokens
    }

    /// 붙잡혔다가 `failClear()` 로 풀리면 실패한다. 토큰은 남는다.
    func clear() async throws {
        await withCheckedContinuation { continuation in
            pendingClear = continuation
            enteredWaiters.forEach { $0.resume() }
            enteredWaiters.removeAll()
        }
        throw FailingTokenStore.Failure()
    }

    func waitUntilClearEntered() async {
        if pendingClear != nil {
            return
        }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func failClear() {
        pendingClear?.resume()
        pendingClear = nil
    }
}
