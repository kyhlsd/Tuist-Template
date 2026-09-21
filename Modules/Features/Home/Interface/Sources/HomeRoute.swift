//
//  HomeRoute.swift
//  HomeInterface
//

import Domain
import Navigation

/// Home 이 제공하는 화면들.
///
/// Home 내부든 다른 피처든, Home 의 화면으로 가려면 이 값을 `Routing.push` 한다.
/// 값을 실제 화면으로 바꾸는 것은 App 이다. 그래서 다른 피처는 Home 구현을 몰라도 된다.
///
/// 연관값에는 엔티티 전체가 아니라 식별자만 담는다. 딥링크로도 만들 수 있고,
/// 이동한 화면이 항상 최신 데이터를 다시 읽게 된다.
public enum HomeRoute: Route {
    case detail(id: Item.ID)
}
