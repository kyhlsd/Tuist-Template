//
//  ScopedRouter.swift
//  TuistApp
//

import Navigation

/// 탭 하나 또는 모달 하나의 문맥에서 `AppRouter` 를 조작하는 `Routing` 어댑터.
///
/// 뷰모델은 자기가 어느 탭·모달에 있는지 모른 채 `Routing` 만 본다.
/// `AppRouter` 가 문맥마다 하나씩 만들어 캐시하므로 직접 만들지 않는다.
@MainActor
final class ScopedRouter: Routing {
    enum Scope: Hashable {
        case tab(AppTab)
        /// 모달 하나. 그 모달이 떠 있는 동안만 요청을 반영한다.
        case presented(PresentedRoute.ID)
    }

    let scope: Scope
    /// `AppRouter` 가 이 어댑터를 소유하므로 순환을 피하려고 약하게 참조한다.
    private weak var appRouter: AppRouter?

    init(scope: Scope, appRouter: AppRouter) {
        self.scope = scope
        self.appRouter = appRouter
    }

    func push(_ route: some Route) {
        guard let appRoute = AppRoute(route) else {
            assertionFailure("\(type(of: route)) 가 AppRoute 에 없습니다. AppRoute.init?(_:) 에 분기를 추가하세요.")
            return
        }
        updatePath { $0.append(appRoute) }
    }

    func pop() {
        // 루트에서 뒤로 가기는 할 일이 없다.
        updatePath { path in
            guard !path.isEmpty else { return }
            path.removeLast()
        }
    }

    func popToRoot() {
        updatePath { $0.removeAll() }
    }

    func present(_ route: some Route, style: PresentationStyle) {
        guard let appRoute = AppRoute(route) else {
            assertionFailure("\(type(of: route)) 가 AppRoute 에 없습니다. AppRoute.init?(_:) 에 분기를 추가하세요.")
            return
        }
        guard let appRouter, isActive(in: appRouter) else { return }
        appRouter.presented = PresentedRoute(root: appRoute, style: style)
    }

    func dismiss() {
        guard let appRouter, isActive(in: appRouter) else { return }
        appRouter.presented = nil
    }

    private func updatePath(_ body: (inout [AppRoute]) -> Void) {
        guard let appRouter, isActive(in: appRouter) else { return }
        switch scope {
        case let .tab(tab):
            body(&appRouter[path: tab])
        case let .presented(id):
            body(&appRouter[presentedPath: id])
        }
    }

    /// 탭 문맥은 항상 유효하다. 모달 문맥은 자기 모달이 지금 떠 있을 때만 유효하다.
    /// 모달이 닫힌 뒤 늦게 온 요청(비동기 작업 뒤의 push·dismiss 등)이 다음 모달을 바꾸지 않게 한다.
    private func isActive(in appRouter: AppRouter) -> Bool {
        switch scope {
        case .tab:
            true
        case let .presented(id):
            appRouter.presented?.id == id
        }
    }
}
