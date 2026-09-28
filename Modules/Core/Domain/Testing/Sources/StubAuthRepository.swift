//
//  StubAuthRepository.swift
//  DomainTesting
//

import Domain

/// 정해진 결과를 돌려주는 `AuthRepository`.
///
/// 테스트와 데모 앱이 함께 쓴다. 모듈마다 스텁을 새로 만들지 않는다.
/// `sessionStatuses()` 는 `statuses` 를 차례로 보낸 뒤 끝난다.
public struct StubAuthRepository: AuthRepository {
    private let signInResult: Result<Void, AuthError>
    private let signOutResult: Result<Void, AuthError>
    private let statuses: [SessionStatus]

    public init(
        signInResult: Result<Void, AuthError> = .success(()),
        signOutResult: Result<Void, AuthError> = .success(()),
        statuses: [SessionStatus] = [.signedOut]
    ) {
        self.signInResult = signInResult
        self.signOutResult = signOutResult
        self.statuses = statuses
    }

    public func signIn(email _: String, password _: String) async throws(AuthError) {
        try signInResult.get()
    }

    public func signOut() async throws(AuthError) {
        try signOutResult.get()
    }

    public func sessionStatuses() async -> AsyncStream<SessionStatus> {
        let (stream, continuation) = AsyncStream<SessionStatus>.makeStream()
        for status in statuses {
            continuation.yield(status)
        }
        continuation.finish()
        return stream
    }
}
