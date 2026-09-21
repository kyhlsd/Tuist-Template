//
//  ScopedRouterTests.swift
//  TuistAppTests
//

import HomeInterface
import Testing
@testable import TuistApp

@MainActor
@Suite("ScopedRouter")
struct ScopedRouterTests {
    private let appRouter = AppRouter(gate: AllowAllDeepLinkGate())

    @Test("탭 문맥에서 push 하면 그 탭의 스택에 쌓인다")
    func push_tabScope_appendsToTabPath() {
        appRouter.router(for: .home).push(HomeRoute.detail(id: "1"))

        #expect(appRouter[path: .home] == [.home(.detail(id: "1"))])
    }

    @Test("탭 문맥에서 push 해도 모달 스택은 그대로다")
    func push_tabScope_keepsPresentedPath() {
        let modal = presentModal()

        appRouter.router(for: .home).push(HomeRoute.detail(id: "1"))

        #expect(appRouter[presentedPath: modal.id].isEmpty)
    }

    @Test("루트에서 pop 해도 아무 일도 일어나지 않는다")
    func pop_atRoot_keepsPathEmpty() {
        appRouter.router(for: .home).pop()

        #expect(appRouter[path: .home].isEmpty)
    }

    @Test("pop 하면 한 단계 돌아간다")
    func pop_afterPushes_removesLast() {
        let router = appRouter.router(for: .home)
        router.push(HomeRoute.detail(id: "1"))
        router.push(HomeRoute.detail(id: "2"))

        router.pop()

        #expect(appRouter[path: .home] == [.home(.detail(id: "1"))])
    }

    @Test("popToRoot 는 쌓인 경로를 모두 비운다")
    func popToRoot_afterPushes_emptiesPath() {
        let router = appRouter.router(for: .home)
        router.push(HomeRoute.detail(id: "1"))
        router.push(HomeRoute.detail(id: "2"))

        router.popToRoot()

        #expect(appRouter[path: .home].isEmpty)
    }

    @Test("모달 문맥에서 push 하면 모달 스택에 쌓인다")
    func push_presentedScope_appendsToPresentedPath() {
        let modal = presentModal()

        appRouter.router(forPresented: modal.id).push(HomeRoute.detail(id: "1"))

        #expect(appRouter[presentedPath: modal.id] == [.home(.detail(id: "1"))])
    }

    @Test("모달 문맥에서 push 해도 탭 스택은 그대로다")
    func push_presentedScope_keepsTabPath() {
        let modal = presentModal()

        appRouter.router(forPresented: modal.id).push(HomeRoute.detail(id: "1"))

        #expect(appRouter[path: .home].isEmpty)
    }

    @Test("모달이 없을 때 모달 문맥에서 push 하면 무시한다")
    func push_presentedScopeWithoutModal_isIgnored() {
        let modal = presentModal()
        appRouter.presented = nil

        appRouter.router(forPresented: modal.id).push(HomeRoute.detail(id: "1"))

        #expect(appRouter[path: .home].isEmpty)
    }

    @Test("닫힌 모달의 라우터로 늦게 push 해도 다음 모달 스택은 그대로다")
    func push_closedModalRouter_keepsNextModalPath() {
        let first = presentModal(detailID: "A")
        let lateRouter = appRouter.router(forPresented: first.id)
        let second = presentModal(detailID: "B")

        lateRouter.push(HomeRoute.detail(id: "1"))

        #expect(appRouter[presentedPath: second.id].isEmpty)
    }

    @Test("닫힌 모달의 라우터로 늦게 dismiss 해도 다음 모달은 닫히지 않는다")
    func dismiss_closedModalRouter_keepsNextModal() throws {
        let first = presentModal(detailID: "A")
        let lateRouter = appRouter.router(forPresented: first.id)
        let second = presentModal(detailID: "B")

        lateRouter.dismiss()

        #expect(try #require(appRouter.presented).id == second.id)
    }

    @Test("닫힌 모달의 라우터로 늦게 present 해도 다음 모달을 교체하지 않는다")
    func present_closedModalRouter_keepsNextModal() throws {
        let first = presentModal(detailID: "A")
        let lateRouter = appRouter.router(forPresented: first.id)
        let second = presentModal(detailID: "B")

        lateRouter.present(HomeRoute.detail(id: "1"), style: .sheet)

        #expect(try #require(appRouter.presented).id == second.id)
    }

    @Test("present 하면 Route 와 방식으로 모달을 띄운다")
    func present_route_setsPresented() throws {
        appRouter.router(for: .home).present(HomeRoute.detail(id: "1"), style: .fullScreenCover)

        let presented = try #require(appRouter.presented)
        #expect(presented.root == .home(.detail(id: "1")))
        #expect(presented.style == .fullScreenCover)
    }

    @Test("이미 모달이 떠 있으면 교체한다")
    func present_whilePresented_replacesModal() throws {
        let router = appRouter.router(for: .home)
        router.present(HomeRoute.detail(id: "1"), style: .sheet)

        router.present(HomeRoute.detail(id: "2"), style: .sheet)

        let presented = try #require(appRouter.presented)
        #expect(presented.root == .home(.detail(id: "2")))
    }

    @Test("dismiss 하면 모달이 닫힌다")
    func dismiss_whilePresented_clearsPresented() {
        let modal = presentModal()

        appRouter.router(forPresented: modal.id).dismiss()

        #expect(appRouter.presented == nil)
    }

    @Test("같은 탭이면 같은 라우터 인스턴스를 돌려준다")
    func routerForTab_calledTwice_returnsSameInstance() {
        let first = appRouter.router(for: .home)
        let second = appRouter.router(for: .home)

        #expect(first === second)
    }

    @Test("떠 있는 모달의 라우터로 present 하면 다른 모달로 교체한다")
    func present_activeModalRouter_replacesModal() throws {
        let modal = presentModal(detailID: "A")

        appRouter.router(forPresented: modal.id).present(HomeRoute.detail(id: "2"), style: .fullScreenCover)

        #expect(try #require(appRouter.presented).style == .fullScreenCover)
    }

    @Test("같은 모달이면 같은 라우터 인스턴스를 돌려준다")
    func routerForPresented_sameModal_returnsSameInstance() {
        let modal = presentModal()

        let first = appRouter.router(forPresented: modal.id)
        let second = appRouter.router(forPresented: modal.id)

        #expect(first === second)
    }

    @Test("다른 모달이면 다른 라우터 인스턴스를 돌려준다")
    func routerForPresented_otherModal_returnsNewInstance() {
        let first = appRouter.router(forPresented: presentModal(detailID: "A").id)
        let second = appRouter.router(forPresented: presentModal(detailID: "B").id)

        #expect(first !== second)
    }

    /// 라우터 소유 모달을 띄우고 돌려준다. 이미 떠 있으면 교체한다.
    ///
    /// 모달끼리는 `PresentedRoute.id`(매번 새 UUID)로 구분된다. `detailID` 는 루트 화면의 식별자일 뿐이다.
    @discardableResult
    private func presentModal(detailID: String = "9") -> PresentedRoute {
        let modal = PresentedRoute(root: .home(.detail(id: detailID)), style: .sheet)
        appRouter.presented = modal
        return modal
    }
}
