//
//  Router.swift
//  Navigation
//

import Observation
import SwiftUI

/// 내비게이션 스택 하나의 상태.
///
/// 탭마다 하나씩 만들어 `NavigationStack(path: $router.path)` 에 연결한다.
/// 시트·다이얼로그 같은 모달은 다루지 않는다. 모달은 각 화면이 자기 상태로 띄운다.
@Observable
public final class Router: Routing {
    public var path = NavigationPath()

    public init() {}

    public func push(_ route: some Hashable) {
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
}
