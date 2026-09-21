//
//  AppRoute.swift
//  TuistApp
//

import HomeInterface
import Navigation

/// 앱이 아는 모든 피처 Route 를 감싼다. 탭·모달 스택(`[AppRoute]`)의 원소다.
///
/// 피처는 `AppRoute` 를 모르므로 `Routing.push(_:)` 에 자기 Interface 의 Route 를 넘긴다.
/// 그 값을 `AppRoute` 로 바꾸는 곳은 `init?(_:)` 한 곳뿐이다.
/// 피처를 추가하면 case 와 `init?(_:)` 의 분기를 함께 늘린다.
enum AppRoute: Hashable {
    case home(HomeRoute)

    /// 피처가 push 한 Route 를 감싼다. 앱이 모르는 Route 면 `nil` 이다.
    ///
    /// 피처 Route 는 App 에서만 모두 보이므로 런타임 캐스팅으로 판정한다.
    /// 실패를 어떻게 다룰지는 호출부가 정한다.
    init?(_ route: some Route) {
        switch route {
        case let route as HomeRoute:
            self = .home(route)
        default:
            return nil
        }
    }
}
