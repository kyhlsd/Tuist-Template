//
//  FetchItemsUseCase.swift
//  Domain
//
//  템플릿 예시 UseCase. 실제 규칙으로 교체한다.
//

/// 화면에 보여줄 항목 목록을 가져온다.
///
/// UseCase 는 Repository 를 조합하고 도메인 규칙을 적용하는 곳이다. 피처의 뷰모델은 이 프로토콜에 의존하고,
/// 구현(`DefaultFetchItemsUseCase`)은 App 이, 스텁(`StubFetchItemsUseCase`)은 테스트·데모가 넣는다.
///
/// 언제 만드는가: 규칙(정렬·필터·검증)이 있거나 Repository 를 둘 이상 조합할 때.
/// Repository 를 그대로 전달만 하는 UseCase 는 만들지 않는다. 그때는 뷰모델이 Repository 에 직접 의존해도 된다.
public protocol FetchItemsUseCase: Sendable {
    func execute() async throws(ItemError) -> [Item]
}
