//
//  AppRouter.swift
//  TuistApp
//

import Foundation
import Navigation
import Observation

/// 앱 전체의 화면 이동 상태. 선택된 탭, 탭별 스택, 모달 한 단계를 소유한다.
///
/// 뷰는 이 상태를 바인딩만 하고, 뷰모델은 `router(for:)` 가 돌려주는 `Routing` 으로 요청한다.
/// 딥링크·푸시는 모두 `handle(_:)` 한 입구로 들어온다.
///
/// 루트 화면이 나타나기 전(`markReady()` 전)이나 게이트가 거부한 링크는 마지막 하나만 보류했다가
/// `markReady()` 또는 `resumePending()` 에서 연다.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    private(set) var paths: [AppTab: [AppRoute]] = [:]
    var presented: PresentedRoute?

    @ObservationIgnored private var pending: DeepLink?
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private let gate: any DeepLinkGate
    @ObservationIgnored private let parser = DeepLinkParser()
    @ObservationIgnored private var tabRouters: [AppTab: ScopedRouter] = [:]
    @ObservationIgnored private var presentedRouter: ScopedRouter?

    init(gate: any DeepLinkGate) {
        self.gate = gate
    }

    /// 탭의 스택. `NavigationStack(path: $router[path: tab])` 로 바인딩한다.
    subscript(path tab: AppTab) -> [AppRoute] {
        get { paths[tab] ?? [] }
        set { paths[tab] = newValue }
    }

    /// 모달 `id` 의 스택. `NavigationStack(path: $router[presentedPath: presented.id])` 로 바인딩한다.
    ///
    /// 그 모달이 지금 떠 있을 때만 읽고 쓴다. 다른 모달이면 비어 있고 쓰기는 무시된다.
    /// 닫히는 중인 모달의 스택이 다음 모달의 경로를 읽거나 덮어쓰지 않게 한다(D6 과 같은 기준).
    subscript(presentedPath id: PresentedRoute.ID) -> [AppRoute] {
        get { presented?.id == id ? presented?.path ?? [] : [] }
        set {
            guard presented?.id == id else { return }
            presented?.path = newValue
        }
    }

    /// 방식이 `style` 인 모달. `.sheet(item: $router[presented: .sheet])` 처럼 방식별로 바인딩한다.
    ///
    /// 시스템이 닫으며 `nil` 을 쓰면, 지금 떠 있는 모달이 그 방식일 때만 닫는다.
    /// 다른 방식으로 교체되는 중에 이전 표시가 닫히며 새 모달까지 지우는 일을 막는다.
    subscript(presented style: PresentationStyle) -> PresentedRoute? {
        get { presented?.style == style ? presented : nil }
        set {
            if let newValue {
                presented = newValue
            } else if presented?.style == style {
                presented = nil
            }
        }
    }

    // MARK: 뷰모델용 Routing

    /// 탭 문맥의 `Routing`. 같은 탭이면 같은 인스턴스를 돌려준다.
    func router(for tab: AppTab) -> any Routing {
        if let cached = tabRouters[tab] {
            return cached
        }
        let router = ScopedRouter(scope: .tab(tab), appRouter: self)
        tabRouters[tab] = router
        return router
    }

    /// 모달 하나(`id`)의 `Routing`. 같은 모달이면 같은 인스턴스를 돌려준다.
    ///
    /// 모달 안의 화면에는 `router(for:)` 가 아니라 이 값을 넘긴다(`RootView` 가 `makeView(for:router:)` 로 넘긴다).
    /// 탭 라우터를 넘기면 push 가 모달 뒤의 탭 스택에 쌓인다.
    ///
    /// 라우터는 그 모달에 묶여 있다. 모달이 닫힌 뒤 늦게 온 요청은 다음에 뜬 다른 모달에 적용되지 않는다.
    /// 모달은 한 번에 하나이므로 마지막 모달의 라우터만 캐시한다.
    func router(forPresented id: PresentedRoute.ID) -> any Routing {
        if let presentedRouter, presentedRouter.scope == .presented(id) {
            return presentedRouter
        }
        let router = ScopedRouter(scope: .presented(id), appRouter: self)
        presentedRouter = router
        return router
    }

    // MARK: 딥링크

    /// 모든 링크의 입구. 해석할 수 없는 URL 은 무시한다.
    func handle(_ url: URL) {
        guard let link = parser.parse(url) else { return }
        guard isReady, gate.canOpen(link) else {
            pending = link
            return
        }
        pending = nil
        apply(link)
    }

    /// 루트 화면이 나타났을 때 부른다. 보류된 링크가 있으면 연다.
    func markReady() {
        isReady = true
        resumePending()
    }

    /// 보류된 링크를 다시 시도한다. 로그인 등으로 게이트 조건이 바뀐 뒤 부른다.
    func resumePending() {
        guard isReady, let link = pending, gate.canOpen(link) else { return }
        pending = nil
        apply(link)
    }

    private func apply(_ link: DeepLink) {
        presented = nil
        selectedTab = link.tab
        paths[link.tab] = link.path
    }
}
