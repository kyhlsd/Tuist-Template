//
//  RemoteItemRepositoryTests.swift
//  DataTests
//

import Data
import Domain
import DomainTesting
import Foundation
import Networking
import OpenAPIRuntime
import Testing

@Suite("RemoteItemRepository")
struct RemoteItemRepositoryTests {
    private let reporter = SpyDiagnosticReporter()

    @Test("200 응답을 도메인 항목으로 변환한다")
    func fetchItems_ok_mapsToDomain() async throws {
        let body = Operations.ListItems.Output.Ok.Body.json([.init(id: "1", title: "첫 번째")])
        let repository = RemoteItemRepository(client: StubAPI(listItems: .success(.ok(.init(body: body)))), reporter: reporter)

        let items = try await repository.fetchItems()

        #expect(items == [Item(id: "1", title: "첫 번째")])
    }

    @Test("401 응답은 unavailable 로 바뀐다")
    func fetchItems_unauthorized_throwsUnavailable() async {
        let error = Components.Schemas.ErrorResponse(code: "unauthorized", message: "")
        let output = Operations.ListItems.Output.unauthorized(.init(body: .json(error)))
        let repository = RemoteItemRepository(client: StubAPI(listItems: .success(output)), reporter: reporter)

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
    }

    @Test("명세에 없는 응답은 unavailable 로 바뀐다")
    func fetchItems_undocumented_throwsUnavailable() async {
        let output = Operations.ListItems.Output.undocumented(statusCode: 500, UndocumentedPayload())
        let repository = RemoteItemRepository(client: StubAPI(listItems: .success(output)), reporter: reporter)

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
    }

    @Test("호출 자체가 실패하면 unavailable 로 바뀐다")
    func fetchItems_clientThrows_throwsUnavailable() async {
        let repository = RemoteItemRepository(client: StubAPI(listItems: .failure(URLError(.timedOut))), reporter: reporter)

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
    }

    @Test("보고 대상 전송 실패는 요약을 한 번 보고한다")
    func fetchItems_reportableFailure_reportsOnce() async {
        let repository = RemoteItemRepository(
            client: StubAPI(listItems: .failure(wrappedByRuntime(URLError(.cannotConnectToHost)))),
            reporter: reporter
        )

        _ = try? await repository.fetchItems()

        #expect(reporter.reported == [DiagnosticFailure(
            operationID: "listItems",
            errorType: "URLError",
            errorCode: URLError.Code.cannotConnectToHost.rawValue,
            summary: "URLError(\(URLError.Code.cannotConnectToHost.rawValue))",
            requestID: nil
        )])
    }

    @Test("취소와 오프라인은 보고하지 않는다", arguments: [
        URLError.Code.cancelled,
        URLError.Code.notConnectedToInternet,
    ])
    func fetchItems_cancelledOrOffline_doesNotReport(code: URLError.Code) async {
        let repository = RemoteItemRepository(
            client: StubAPI(listItems: .failure(wrappedByRuntime(URLError(code)))),
            reporter: reporter
        )

        _ = try? await repository.fetchItems()

        #expect(reporter.reported.isEmpty)
    }

    @Test("명세에 없는 응답은 서버가 기록하므로 보고하지 않는다")
    func fetchItems_undocumented_doesNotReport() async {
        let output = Operations.ListItems.Output.undocumented(statusCode: 500, UndocumentedPayload())
        let repository = RemoteItemRepository(client: StubAPI(listItems: .success(output)), reporter: reporter)

        _ = try? await repository.fetchItems()

        #expect(reporter.reported.isEmpty)
    }

    @Test("성공하면 보고하지 않는다")
    func fetchItems_ok_doesNotReport() async throws {
        let body = Operations.ListItems.Output.Ok.Body.json([])
        let repository = RemoteItemRepository(
            client: StubAPI(listItems: .success(.ok(.init(body: body)))), reporter: reporter
        )

        _ = try await repository.fetchItems()

        #expect(reporter.reported.isEmpty)
    }

    /// 런타임이 호출부에 던지는 형태로 감싼다.
    private func wrappedByRuntime(_ error: any Error) -> ClientError {
        ClientError(
            operationID: "listItems",
            operationInput: "listItems",
            causeDescription: "Transport threw an error.",
            underlyingError: error
        )
    }
}

/// 정해진 결과를 돌려주는 `APIProtocol`. 이 파일에서만 쓰므로 Testing 모듈로 빼지 않는다.
///
/// 명세에 operation 이 늘면 여기에도 메서드가 늘어난다. 쓰지 않는 operation 은 기록 후 실패한다.
private struct StubAPI: APIProtocol {
    let listItems: Result<Operations.ListItems.Output, any Error>

    func listItems(_: Operations.ListItems.Input) async throws -> Operations.ListItems.Output {
        try listItems.get()
    }

    func login(_: Operations.Login.Input) async throws -> Operations.Login.Output {
        Issue.record("이 테스트는 login 을 호출하지 않아야 한다")
        throw UnexpectedCall()
    }

    func refreshToken(_: Operations.RefreshToken.Input) async throws -> Operations.RefreshToken.Output {
        Issue.record("이 테스트는 refreshToken 을 호출하지 않아야 한다")
        throw UnexpectedCall()
    }
}

private struct UnexpectedCall: Error {}
