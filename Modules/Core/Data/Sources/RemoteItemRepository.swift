//
//  RemoteItemRepository.swift
//  Data
//

import Diagnostics
import Domain
import Networking

/// 서버에서 항목을 가져오는 `ItemRepository` 구현.
///
/// 생성된 `APIProtocol` 에 의존한다. 기본 URL, 인증, 재시도는 App 이 `APIClientFactory` 로 조립한다.
///
/// 보고 규칙: 생성 클라이언트를 부르는 `catch` 에서 `NetworkFailure.describe(_:)` 로 판정해
/// 보고 대상이면 `reporter` 로 보고한다. 응답 디코딩 실패는 미들웨어에 보이지 않고 여기서만 잡히기 때문이다.
/// 새 Repository 도 같은 규칙을 따른다.
///
/// 보고의 operation ID 는 실제로 실패한 요청이다. 토큰 갱신이 전송 단계에서 실패하면 refresh 클라이언트의
/// `ClientError` 가 다시 감싸지지 않고 올라오므로, `listItems` 를 불렀어도 `refreshToken` 으로 찍힌다.
public struct RemoteItemRepository: ItemRepository {
    private let client: any APIProtocol
    private let reporter: any DiagnosticReporting

    public init(client: any APIProtocol, reporter: any DiagnosticReporting) {
        self.client = client
        self.reporter = reporter
    }

    public func fetchItems() async throws(ItemError) -> [Item] {
        let output: Operations.ListItems.Output
        do {
            output = try await client.listItems()
        } catch {
            // 전송 실패의 종류는 화면이 구분하지 않으므로 도메인 에러 하나로 모은다.
            // 본문 디코딩 실패와 콘텐츠 타입 불일치도 생성 코드가 ClientError 로 던지므로 여기로 온다.
            report(error)
            throw .unavailable
        }

        switch output {
        case let .ok(ok):
            do {
                return try ok.body.json.map { $0.toDomain() }
            } catch {
                // 지금 명세의 200 본문은 JSON 하나뿐이라 여기는 실행되지 않는다. 서버가 보낸 콘텐츠 타입이
                // 명세와 다르거나 디코딩에 실패하면 생성 코드가 ClientError 를 던져 위에서 unavailable 이 된다.
                // 명세에 JSON 이 아닌 콘텐츠 타입이 추가되면 그 본문이 여기로 와 invalidData 가 된다.
                throw .invalidData
            }
        case .unauthorized, .undocumented:
            // 서버가 돌려준 응답이라 서버 로그에 남는다. 클라이언트는 보고하지 않는다.
            throw .unavailable
        }
    }

    /// 서버가 볼 수 없는 에러만 보고한다. 결과를 기다리지 않는다.
    private func report(_ error: any Error) {
        let failure = NetworkFailure.describe(error)
        guard failure.isReportable else {
            return
        }
        reporter.report(DiagnosticFailure(
            operationID: failure.operationID,
            errorType: failure.errorType,
            errorCode: failure.errorCode,
            summary: failure.summary,
            requestID: failure.requestID
        ))
    }
}
