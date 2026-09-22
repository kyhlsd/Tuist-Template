//
//  TokenRefresher.swift
//  Networking
//

import os

/// 401 을 받은 요청들의 토큰 갱신을 한 번으로 모은다.
///
/// 진행 중인 갱신이 있으면 새 호출은 그 `Task` 를 기다린다. actor 는 `await` 지점에서
/// 재진입할 수 있으므로, `inFlight` 확인과 저장은 항상 `await` 없이 이어서 한다.
actor TokenRefresher {
    typealias Refresh = @Sendable (_ refreshToken: String) async throws -> AuthTokens

    private let store: any TokenStore
    private let refresh: Refresh
    private let onSessionExpired: @Sendable () async -> Void
    private let logger: Logger
    private var inFlight: Task<AuthTokens, any Error>?
    /// 저장에 실패한 새 토큰. 저장소에는 이전 토큰이 남아 있으므로 저장이 성공하거나 세션이 끝날 때까지
    /// 저장소보다 먼저 읽는다. 앱을 다시 시작하면 사라진다.
    ///
    /// 값이 있는 동안에는 저장소를 읽지 않는다. 로그인·로그아웃처럼 저장소에 직접 쓰는 경로가 생기면
    /// 이 타입을 거치게 하거나 `unsaved` 를 비우는 진입점을 함께 둔다. 그러지 않으면 새 토큰이 가려진다.
    private var unsaved: AuthTokens?

    /// - Parameters:
    ///   - refresh: refresh token 으로 새 토큰을 받아 온다. 서버가 거절하면
    ///     `AuthenticationError.sessionExpired` 를 던진다.
    ///   - onSessionExpired: 세션이 끝났을 때 한 번 호출된다.
    ///   - logger: 저장소 실패(갱신은 계속 진행)를 남긴다. 기본값은 아무것도 남기지 않는다.
    init(
        store: any TokenStore,
        refresh: @escaping Refresh,
        onSessionExpired: @escaping @Sendable () async -> Void,
        logger: Logger = Logger(.disabled)
    ) {
        self.store = store
        self.refresh = refresh
        self.onSessionExpired = onSessionExpired
        self.logger = logger
    }

    func currentAccessToken() async throws -> String? {
        try await loadTokens()?.accessToken
    }

    /// 새 access token 을 돌려준다.
    ///
    /// - Parameter rejected: 401 을 받은 요청이 쓴 access token. 저장소의 토큰이 이미
    ///   이것과 다르면 다른 호출이 갱신을 끝낸 것이므로 네트워크 호출 없이 현재 토큰을 쓴다.
    func refreshedAccessToken(rejected: String?) async throws -> String {
        if let inFlight {
            return try await inFlight.value.accessToken
        }

        // 토큰이 없으면 로그인 전이거나 만료 처리가 이미 끝난 상태다. 지울 것도 없고,
        // 만료 뒤 늦게 도착한 401 이 콜백을 다시 부르면 안 되므로 에러만 던진다.
        guard let current = try await loadTokens() else {
            throw AuthenticationError.sessionExpired
        }
        if current.accessToken != rejected {
            return current.accessToken
        }

        // 저장소를 읽는 동안 다른 호출이 갱신을 시작했을 수 있다.
        if let inFlight {
            return try await inFlight.value.accessToken
        }

        let task = makeRefreshTask(refreshToken: current.refreshToken)
        inFlight = task
        defer { inFlight = nil }
        return try await task.value.accessToken
    }

    private func makeRefreshTask(refreshToken: String) -> Task<AuthTokens, any Error> {
        Task {
            let tokens: AuthTokens
            do {
                tokens = try await refresh(refreshToken)
            } catch AuthenticationError.sessionExpired {
                // 같은 Task 를 기다리는 호출자들은 에러만 받는다. 정리와 알림은 여기서 한 번만 한다.
                await expireSession()
                throw AuthenticationError.sessionExpired
            }

            do {
                try await store.save(tokens)
                unsaved = nil
            } catch {
                // 서버가 refresh token 을 교체했다면 이전 토큰은 이미 무효다. 저장에 실패했다고 새 토큰까지
                // 버리면 다음 갱신에서 세션이 끝나므로, 메모리에 들고 있으면서 실패는 로그로 남긴다.
                unsaved = tokens
                logger.error("토큰 저장 실패: \(String(describing: type(of: error)), privacy: .public)")
            }
            return tokens
        }
    }

    private func loadTokens() async throws -> AuthTokens? {
        if let unsaved {
            return unsaved
        }
        return try await store.load()
    }

    /// 토큰을 지우고 만료를 알린다.
    ///
    /// 삭제에 실패해도 서버는 이미 세션을 거절했으므로 만료는 알린다. 남은 토큰은 다음 401 에서
    /// 다시 거절되어 삭제가 재시도된다.
    private func expireSession() async {
        unsaved = nil
        do {
            try await store.clear()
        } catch {
            logger.error("토큰 삭제 실패: \(String(describing: type(of: error)), privacy: .public)")
        }
        await onSessionExpired()
    }
}
