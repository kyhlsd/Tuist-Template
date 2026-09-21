//
//  Router.swift
//  Navigation
//

import Observation
import SwiftUI

/// 데모 앱·프리뷰용 단독 라우터.
///
/// 앱은 탭·모달·딥링크를 함께 다루는 App 타깃의 `AppRouter` 를 쓴다. 피처 데모 앱은
/// `AppRouter` 를 볼 수 없으므로 이 타입으로 스택 하나를 흉내 낸다.
/// `NavigationStack(path: $router.path)` 에 연결한다.
///
/// 모달은 `presented` 에 기록만 한다. 데모에서 띄우려면 이 값을 보고 직접 표시한다.
@Observable
public final class Router: Routing {
    public var path = NavigationPath()
    public private(set) var presented: (route: AnyHashable, style: PresentationStyle)?

    public init() {}

    public func push(_ route: some Route) {
        path.append(route)
    }

    public func pop() {
        // 루트에서 뒤로 가기는 할 일이 없다. 빈 경로에서 removeLast 는 크래시이므로 막는다.
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path.removeLast(path.count)
    }

    public func present(_ route: some Route, style: PresentationStyle) {
        presented = (route: AnyHashable(route), style: style)
    }

    public func dismiss() {
        presented = nil
    }
}
