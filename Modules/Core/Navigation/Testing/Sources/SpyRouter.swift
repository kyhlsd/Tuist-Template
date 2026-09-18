//
//  SpyRouter.swift
//  NavigationTesting
//

import Navigation

/// 이동 요청을 기록만 하는 `Routing`.
///
/// ```swift
/// let router = SpyRouter()
/// viewModel.select(item)
/// #expect(router.pushedRoutes == [HomeRoute.detail(id: item.id)])
/// ```
public final class SpyRouter: Routing {
    public private(set) var pushedRoutes: [AnyHashable] = []
    public private(set) var popCount = 0
    public private(set) var popToRootCount = 0

    public init() {}

    public func push(_ route: some Hashable) {
        pushedRoutes.append(route)
    }

    public func pop() {
        popCount += 1
    }

    public func popToRoot() {
        popToRootCount += 1
    }
}
