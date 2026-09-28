//
//  StubFetchItemsUseCase.swift
//  DomainTesting
//

import Domain

/// 정해진 결과를 돌려주는 `FetchItemsUseCase`.
///
/// 뷰모델 테스트와 데모 앱이 쓴다. UseCase 의 규칙은 `DefaultFetchItemsUseCase` 테스트가 따로 검증하므로
/// 뷰모델 테스트는 규칙을 거치지 않고 결과만 정한다.
public struct StubFetchItemsUseCase: FetchItemsUseCase {
    private let result: Result<[Item], ItemError>

    public init(result: Result<[Item], ItemError>) {
        self.result = result
    }

    public func execute() async throws(ItemError) -> [Item] {
        try result.get()
    }
}
