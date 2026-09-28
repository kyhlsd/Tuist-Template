//
//  RemoteAuthRepository.swift
//  Data
//

import Auth
import Diagnostics
import Domain
import Networking

/// 서버에 로그인하고 토큰을 `AuthSession` 에 맡기는 `AuthRepository` 구현.
///
/// 로그인은 명세의 `login` operation 을 부른다. 명세에 logout 이 없으므로 로그아웃은 로컬 토큰 삭제뿐이다.
/// 토큰 저장·갱신·세션 상태는 `AuthSession` 이 맡는다. 인증 미들웨어와 같은 인스턴스를 써야 한다(App 이 조립한다).
///
/// 보고 규칙은 `RemoteItemRepository` 와 같다. 생성 클라이언트를 부르는 `catch` 에서만 `NetworkFailure` 로 판정해 보고한다.
public struct RemoteAuthRepository: AuthRepository {
    private let client: any APIProtocol
    private let session: any SessionManaging
    private let reporter: any DiagnosticReporting

    public init(client: any APIProtocol, session: any SessionManaging, reporter: any DiagnosticReporting) {
        self.client = client
        self.session = session
        self.reporter = reporter
    }

    public func signIn(email: String, password: String) async throws(AuthError) {
        let output: Operations.Login.Output
        do {
            output = try await client.login(body: .json(.init(email: email, password: password)))
        } catch {
            // 전송 실패의 종류는 화면이 구분하지 않으므로 "다시 시도" 하나로 모은다.
            reporter.reportNetworkFailure(error)
            throw .unavailable
        }

        let tokens: AuthTokens
        switch output {
        case let .ok(ok):
            // 지금 명세의 200 본문은 JSON 하나뿐이라 던지지 않는다. 콘텐츠 타입이 늘면 JSON 이 아닌 본문이 여기로 온다.
            guard let pair = try? ok.body.json else {
                throw .unavailable
            }
            tokens = AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
        case .unauthorized:
            throw .invalidCredentials
        case .undocumented:
            // 서버가 돌려준 응답이라 서버 로그에 남는다. 클라이언트는 보고하지 않는다.
            throw .unavailable
        }

        do {
            try await session.signIn(with: tokens)
        } catch {
            // 토큰을 보관하지 못했거나(AuthSession 이 로그를 남긴다), 저장하는 동안 로그아웃이 먼저 끝났다.
            // 어느 쪽이든 로그인되지 않았으므로 사용자가 다시 시도하면 된다.
            throw .unavailable
        }
    }

    public func signOut() async throws(AuthError) {
        do {
            try await session.signOut()
        } catch {
            // 메모리의 토큰은 이미 비웠고 `.signedOut` 도 알렸다. 남은 토큰은 다음 로그인 때 덮인다.
            throw .unavailable
        }
    }

    public func sessionStatuses() async -> AsyncStream<SessionStatus> {
        let states = await session.states()
        let (stream, continuation) = AsyncStream<SessionStatus>.makeStream()
        let forwarding = Task {
            for await state in states {
                continuation.yield(Self.status(from: state))
            }
            continuation.finish()
        }
        // 구독자가 떠나면 전달을 멈춘다. `states` 순회가 끝나면서 AuthSession 의 구독도 풀린다.
        continuation.onTermination = { _ in forwarding.cancel() }
        return stream
    }

    private static func status(from state: AuthSessionState) -> SessionStatus {
        switch state {
        case .signedIn:
            .signedIn
        case .signedOut:
            .signedOut
        case .expired:
            .expired
        }
    }
}
