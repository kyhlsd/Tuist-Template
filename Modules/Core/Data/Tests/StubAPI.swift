//
//  StubAPI.swift
//  DataTests
//

import Networking
import Testing

/// 정해진 결과를 돌려주는 `APIProtocol`. Data 테스트끼리만 쓰므로 Testing 모듈로 빼지 않는다.
///
/// 결과를 정하지 않은 operation 은 호출되면 기록 후 실패한다.
/// 명세에 operation 이 늘면 여기에도 메서드가 늘어난다.
struct StubAPI: APIProtocol {
    private let listItems: Result<Operations.ListItems.Output, any Error>?
    private let login: Result<Operations.Login.Output, any Error>?

    init(
        listItems: Result<Operations.ListItems.Output, any Error>? = nil,
        login: Result<Operations.Login.Output, any Error>? = nil
    ) {
        self.listItems = listItems
        self.login = login
    }

    func listItems(_: Operations.ListItems.Input) async throws -> Operations.ListItems.Output {
        guard let listItems else {
            Issue.record("이 테스트는 listItems 를 호출하지 않아야 한다")
            throw UnexpectedCall()
        }
        return try listItems.get()
    }

    func login(_: Operations.Login.Input) async throws -> Operations.Login.Output {
        guard let login else {
            Issue.record("이 테스트는 login 을 호출하지 않아야 한다")
            throw UnexpectedCall()
        }
        return try login.get()
    }

    func refreshToken(_: Operations.RefreshToken.Input) async throws -> Operations.RefreshToken.Output {
        Issue.record("이 테스트는 refreshToken 을 호출하지 않아야 한다")
        throw UnexpectedCall()
    }
}

private struct UnexpectedCall: Error {}
