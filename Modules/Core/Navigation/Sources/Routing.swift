//
//  Routing.swift
//  Navigation
//

/// 뷰모델이 화면 이동을 요청하는 창구.
///
/// 뷰모델은 `Router` 가 아니라 이 프로토콜에 의존한다. 테스트에서는
/// NavigationTesting 의 `SpyRouter` 로 바꿔 어떤 Route 를 요청했는지 확인한다.
///
/// Route 는 각 피처 Interface 의 `Hashable` 값이다. (예: `HomeRoute.detail(id:)`)
/// 다른 피처로 이동할 때도 그 피처의 Interface 에 있는 Route 만 쓰므로
/// 피처끼리 구현을 import 하지 않는다.
public protocol Routing: AnyObject {
    func push(_ route: some Hashable)
    func pop()
    func popToRoot()
}
