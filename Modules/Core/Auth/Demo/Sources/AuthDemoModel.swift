//
//  AuthDemoModel.swift
//  AuthDemo
//

import Auth
import Foundation
import Observation
import os

/// 저장소·서버 모드를 고르고 `AuthSession` 을 조작하는 데모 화면 상태.
///
/// 실패는 삼키지 않고 `lastError` 에 동작 이름과 함께 남겨 화면에 보여 준다.
/// 사용자 동작을 시작할 때 비우므로 화면의 에러는 마지막 동작의 것이다.
@MainActor
@Observable
final class AuthDemoModel {
    var storeKind: DemoTokenStoreKind = .keychain {
        didSet {
            guard storeKind != oldValue else { return }
            replaceSession()
        }
    }

    /// 화면에서 고른 서버 응답. 서버가 이 값을 쓰는 곳은 갱신뿐이라 `refresh()` 가 갱신 직전에 서버에 맞춘다.
    /// 바뀔 때마다 `Task` 로 보내면 빠르게 여러 번 바꿨을 때 도착 순서가 보장되지 않는다.
    var serverMode: DemoRefreshServer.Mode = .success

    private(set) var state: AuthSessionState?
    /// 마지막으로 읽은 access token. 없으면 `nil`.
    private(set) var accessToken: String?
    private(set) var lastError: String?
    /// 갱신이 진행 중인지. 화면은 이 동안 갱신 버튼을 막는다.
    private(set) var isRefreshing = false
    /// 세션을 새로 만들 때마다 바뀐다. 화면이 이 값으로 `states()` 구독을 다시 한다.
    private(set) var sessionGeneration = 0

    private let server = DemoRefreshServer()
    private var session: AuthSession

    init() {
        session = Self.makeSession(kind: .keychain, server: server)
    }

    /// 현재 세션의 상태 스트림을 구독한다. 호출한 `Task` 가 취소되면 끝난다.
    func observeStates() async {
        let session = session
        for await state in await session.states() {
            guard session === self.session else { return }
            self.state = state
            // 상태 알림은 사용자 동작이 아니다. 방금 끝난 동작(예: 만료된 갱신)의 에러 문구를 지우지 않는다.
            // 이 읽기는 대개 에러를 덮지 않는다. 로그아웃·만료 뒤에는 `AuthSession` 이 저장소를 읽지 않고 nil 을 돌려준다.
            // 첫 값과 `.signedIn` 뒤에는 저장소를 읽으므로, 그 읽기가 실패하면 직전 동작의 에러가 "토큰 읽기 실패" 로 덮일 수 있다.
            await perform("토큰 읽기", clearsError: false) { _ in }
        }
    }

    func signIn() async {
        await perform("로그인") { try await $0.signIn(with: DemoRefreshServer.issueTokens()) }
    }

    func signOut() async {
        await perform("로그아웃") { try await $0.signOut() }
    }

    func readToken() async {
        await perform("토큰 읽기") { _ in }
    }

    /// 저장된 access token 을 서버가 거절했다고 보고 갱신한다.
    ///
    /// 한 번에 하나만 실행한다. 모드를 서버에 맞춘 뒤 서버가 응답하기까지 사이에 다른 갱신의 `setMode` 가
    /// 끼어들면, 앞선 갱신이 나중에 고른 모드로 응답받는다. `setMode` 를 부르는 곳은 여기뿐이다.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await server.setMode(serverMode)
        await perform("갱신") { session in
            let current = try await session.currentAccessToken()
            _ = try await session.refreshedAccessToken(rejected: current)
        }
    }

    /// `operation` 뒤에 현재 토큰을 다시 읽는다. 실패하면 동작 이름과 에러를 `lastError` 에 남긴다.
    ///
    /// 기다리는 동안 저장소를 바꿔 세션이 교체됐으면 결과를 버린다. 이전 세션의 토큰·에러가 새 세션 화면에 섞이지 않게 한다.
    private func perform(
        _ name: String,
        clearsError: Bool = true,
        _ operation: (AuthSession) async throws -> Void
    ) async {
        let session = session
        if clearsError {
            lastError = nil
        }
        do {
            try await operation(session)
            let token = try await session.currentAccessToken().value
            guard session === self.session else { return }
            accessToken = token
        } catch {
            guard session === self.session else { return }
            lastError = "\(name) 실패: \(String(describing: error))"
        }
    }

    private func replaceSession() {
        session = Self.makeSession(kind: storeKind, server: server)
        state = nil
        accessToken = nil
        lastError = nil
        sessionGeneration += 1
    }

    private static func makeSession(kind: DemoTokenStoreKind, server: DemoRefreshServer) -> AuthSession {
        AuthSession(
            store: kind.makeStore(),
            refresh: { refreshToken in try await server.refresh(refreshToken) },
            logger: Logger(
                subsystem: Bundle.main.bundleIdentifier ?? LogConstants.fallbackSubsystem,
                category: LogConstants.category
            )
        )
    }
}

private enum LogConstants {
    static let fallbackSubsystem = "AuthDemo"
    static let category = "AuthSession"
}
