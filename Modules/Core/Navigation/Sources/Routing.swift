//
//  Routing.swift
//  Navigation
//

/// 뷰모델이 화면 이동을 요청하는 창구.
///
/// 뷰모델은 구체 라우터가 아니라 이 프로토콜에 의존한다. 테스트에서는
/// NavigationTesting 의 `SpyRouter` 로 바꿔 어떤 Route 를 요청했는지 확인한다.
///
/// Route 는 각 피처 Interface 의 `Route` 값이다. (예: `HomeRoute.detail(id:)`)
/// 다른 피처로 이동할 때도 그 피처의 Interface 에 있는 Route 만 쓰므로
/// 피처끼리 구현을 import 하지 않는다.
///
/// ## 모달의 경계
///
/// `present(_:style:)` 로 띄운 모달은 라우터가 소유한다. 한 번에 한 단계만 뜨고,
/// 딥링크·푸시가 도착하면 라우터가 닫는다. 딥링크로 닫혀야 하는 화면은 이 방식으로 띄운다.
///
/// 확인 다이얼로그·알럿처럼 화면 안에서 끝나는 짧은 모달은 계속 각 화면의 로컬 상태로 띄워도 된다.
/// 다만 라우터는 그 모달을 모르므로 딥링크가 와도 닫지 않는다.
public protocol Routing: AnyObject {
    func push(_ route: some Route)
    func pop()
    func popToRoot()
    /// 모달을 띄운다. 이미 떠 있으면 교체한다(중첩하지 않는다).
    func present(_ route: some Route, style: PresentationStyle)
    /// 라우터가 띄운 모달을 닫는다.
    func dismiss()
}
