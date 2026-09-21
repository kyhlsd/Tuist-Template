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
    /// `present(_:style:)` 호출 한 번의 기록.
    public struct Presentation: Hashable {
        public let route: AnyHashable
        public let style: PresentationStyle

        public init(route: some Route, style: PresentationStyle) {
            self.route = AnyHashable(route)
            self.style = style
        }
    }

    public private(set) var pushedRoutes: [AnyHashable] = []
    public private(set) var popCount = 0
    public private(set) var popToRootCount = 0
    public private(set) var presentedRoutes: [Presentation] = []
    public private(set) var dismissCount = 0

    public init() {}

    public func push(_ route: some Route) {
        pushedRoutes.append(route)
    }

    public func pop() {
        popCount += 1
    }

    public func popToRoot() {
        popToRootCount += 1
    }

    public func present(_ route: some Route, style: PresentationStyle) {
        presentedRoutes.append(Presentation(route: route, style: style))
    }

    public func dismiss() {
        dismissCount += 1
    }
}
