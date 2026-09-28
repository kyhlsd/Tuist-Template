//
//  RemoteAuthRepositoryTests.swift
//  DataTests
//

@testable import Auth
import AuthTesting
import Data
import Diagnostics
import DiagnosticsTesting
import Domain
import Foundation
import Networking
import OpenAPIRuntime
import Testing

@Suite("RemoteAuthRepository", .timeLimit(.minutes(1)))
struct RemoteAuthRepositoryTests {
    private let reporter = SpyDiagnosticReporter()
    private let store = InMemoryTokenStore()

    @Test("200 응답이면 토큰을 저장하고 signedIn 을 알린다")
    func signIn_ok_savesTokensAndEmitsSignedIn() async throws {
        let pair = Components.Schemas.TokenPair(accessToken: "access", refreshToken: "refresh")
        let repository = makeRepository(login: .success(.ok(.init(body: .json(pair)))))
        var statuses = await repository.sessionStatuses().makeAsyncIterator()
        _ = await statuses.next() // 현재 상태(.signedOut)

        try await repository.signIn(email: "user@example.com", password: "password")

        #expect(await store.tokens == AuthTokens(accessToken: "access", refreshToken: "refresh"))
        #expect(await statuses.next() == .signedIn)
    }

    @Test("401 응답은 invalidCredentials 로 바뀌고 저장·보고하지 않는다")
    func signIn_unauthorized_throwsInvalidCredentials() async {
        let error = Components.Schemas.ErrorResponse(code: "unauthorized", message: "")
        let repository = makeRepository(login: .success(.unauthorized(.init(body: .json(error)))))

        await #expect(throws: AuthError.invalidCredentials) {
            try await repository.signIn(email: "user@example.com", password: "wrong")
        }
        #expect(await store.saveCount == 0)
        #expect(reporter.reported.isEmpty)
    }

    @Test("명세에 없는 응답은 unavailable 로 바뀌고 서버가 기록하므로 보고하지 않는다")
    func signIn_undocumented_throwsUnavailableWithoutReport() async {
        let repository = makeRepository(login: .success(.undocumented(statusCode: 500, UndocumentedPayload())))

        await #expect(throws: AuthError.unavailable) {
            try await repository.signIn(email: "user@example.com", password: "password")
        }
        #expect(reporter.reported.isEmpty)
    }

    @Test("호출 자체가 실패하면 unavailable 로 바뀐다")
    func signIn_clientThrows_throwsUnavailable() async {
        let repository = makeRepository(login: .failure(URLError(.timedOut)))

        await #expect(throws: AuthError.unavailable) {
            try await repository.signIn(email: "user@example.com", password: "password")
        }
    }

    @Test("보고 대상 전송 실패는 login 요약을 한 번 보고한다")
    func signIn_reportableFailure_reportsOnce() async {
        let cause = URLError(.cannotConnectToHost)
        let repository = makeRepository(login: .failure(ClientError(
            operationID: "login",
            operationInput: "login",
            causeDescription: "Transport threw an error.",
            underlyingError: cause
        )))

        _ = try? await repository.signIn(email: "user@example.com", password: "password")

        #expect(reporter.reported == [DiagnosticFailure(
            operationID: "login",
            errorType: "URLError",
            errorCode: cause.code.rawValue,
            summary: "URLError(\(cause.code.rawValue))",
            requestID: nil
        )])
    }

    @Test("로그아웃하면 저장소를 비우고 signedOut 을 알린다")
    func signOut_clearsStoreAndEmitsSignedOut() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "access", refreshToken: "refresh"))
        let repository = makeRepository(store: store)
        var statuses = await repository.sessionStatuses().makeAsyncIterator()
        _ = await statuses.next() // 현재 상태(.signedIn)

        try await repository.signOut()

        #expect(await store.tokens == nil)
        #expect(await statuses.next() == .signedOut)
    }

    @Test("토큰 저장에 실패하면 unavailable 로 바뀌고 보고하지 않는다")
    func signIn_storeFails_throwsUnavailableWithoutReport() async {
        let pair = Components.Schemas.TokenPair(accessToken: "access", refreshToken: "refresh")
        let repository = makeRepository(
            store: FailingTokenStore(tokens: nil, saveFailures: 1),
            login: .success(.ok(.init(body: .json(pair))))
        )

        await #expect(throws: AuthError.unavailable) {
            try await repository.signIn(email: "user@example.com", password: "password")
        }
        #expect(reporter.reported.isEmpty)
    }

    @Test("로그아웃 삭제에 실패하면 unavailable 로 바뀌지만 signedOut 은 온다")
    func signOut_storeFails_throwsUnavailableAndEmitsSignedOut() async {
        let repository = makeRepository(
            store: FailingTokenStore(tokens: AuthTokens(accessToken: "a", refreshToken: "r"), failsClear: true)
        )
        var statuses = await repository.sessionStatuses().makeAsyncIterator()
        _ = await statuses.next() // 현재 상태(.signedIn)

        await #expect(throws: AuthError.unavailable) {
            try await repository.signOut()
        }
        #expect(await statuses.next() == .signedOut)
    }

    @Test("상태 구독을 취소하면 AuthSession 의 구독도 정리된다")
    func sessionStatuses_cancelled_releasesSessionSubscription() async {
        let session = makeSession(store: store)
        let repository = RemoteAuthRepository(client: StubAPI(), session: session, reporter: reporter)
        let statuses = await repository.sessionStatuses()
        let consumer = Task {
            for await _ in statuses {}
        }

        consumer.cancel()
        await consumer.value

        // 전달 Task 가 멈추지 않으면 여기서 끝나지 않아 시간 제한에 걸린다.
        await session.waitUntilNoSubscribers()
    }

    private func makeRepository(
        store: (any TokenStore)? = nil,
        login: Result<Operations.Login.Output, any Error>? = nil
    ) -> RemoteAuthRepository {
        RemoteAuthRepository(
            client: StubAPI(login: login),
            session: makeSession(store: store ?? self.store),
            reporter: reporter
        )
    }

    private func makeSession(store: any TokenStore) -> AuthSession {
        // 로그인·로그아웃은 갱신하지 않는다.
        AuthSession(store: store, refresh: { _ in throw AuthenticationError.refreshFailed })
    }
}
