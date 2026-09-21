//
//  AppRouterTests.swift
//  TuistAppTests
//

import Foundation
import HomeInterface
import Testing
@testable import TuistApp

@MainActor
@Suite("AppRouter")
struct AppRouterTests {
    private let detailPath: [AppRoute] = [.home(.detail(id: "1"))]

    @Test("준비 전에 온 링크는 상태를 바꾸지 않는다")
    func handle_beforeReady_keepsState() throws {
        let router = AppRouter(gate: AllowAllDeepLinkGate())

        try router.handle(Self.url("tuistapp://home/items/1"))

        #expect(router[path: .home].isEmpty)
    }

    @Test("준비 전에 온 링크는 markReady 에서 적용된다")
    func markReady_withPendingLink_appliesLink() throws {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        try router.handle(Self.url("tuistapp://home/items/1"))

        router.markReady()

        #expect(router[path: .home] == detailPath)
    }

    @Test("준비 후에 온 링크는 즉시 적용된다")
    func handle_afterReady_appliesImmediately() throws {
        let router = Self.readyRouter()

        try router.handle(Self.url("tuistapp://home/items/1"))

        #expect(router[path: .home] == detailPath)
    }

    @Test("링크를 적용하면 모달이 닫힌다")
    func handle_withPresented_dismissesModal() throws {
        let router = Self.readyRouter()
        router.presented = PresentedRoute(root: .home(.detail(id: "9")), style: .sheet)

        try router.handle(Self.url("tuistapp://home/items/1"))

        #expect(router.presented == nil)
    }

    @Test("링크를 적용하면 기존 스택을 교체한다")
    func handle_withExistingStack_replacesStack() throws {
        let router = Self.readyRouter()
        router[path: .home] = [.home(.detail(id: "8")), .home(.detail(id: "9"))]

        try router.handle(Self.url("tuistapp://home/items/1"))

        #expect(router[path: .home] == detailPath)
    }

    @Test("게이트가 거부하면 보류한다")
    func handle_gateDenies_keepsState() throws {
        let gate = ToggleGate(isOpen: false)
        let router = AppRouter(gate: gate)
        router.markReady()

        try router.handle(Self.url("tuistapp://home/items/1"))

        #expect(router[path: .home].isEmpty)
    }

    @Test("게이트가 허용으로 바뀐 뒤 resumePending 하면 보류된 링크가 적용된다")
    func resumePending_afterGateOpens_appliesLink() throws {
        let gate = ToggleGate(isOpen: false)
        let router = AppRouter(gate: gate)
        router.markReady()
        try router.handle(Self.url("tuistapp://home/items/1"))
        gate.isOpen = true

        router.resumePending()

        #expect(router[path: .home] == detailPath)
    }

    @Test("준비 전에는 resumePending 을 불러도 보류된 링크를 적용하지 않는다")
    func resumePending_beforeReady_keepsState() throws {
        let router = AppRouter(gate: ToggleGate(isOpen: true))
        try router.handle(Self.url("tuistapp://home/items/1"))

        router.resumePending()

        #expect(router[path: .home].isEmpty)
    }

    @Test("준비 전 resumePending 뒤에도 보류된 링크는 markReady 에서 적용된다")
    func markReady_afterEarlyResumePending_appliesLink() throws {
        let router = AppRouter(gate: ToggleGate(isOpen: true))
        try router.handle(Self.url("tuistapp://home/items/1"))
        router.resumePending()

        router.markReady()

        #expect(router[path: .home] == detailPath)
    }

    @Test("보류 중 새 링크가 오면 마지막 것만 적용된다")
    func markReady_withTwoPendingLinks_appliesLastOnly() throws {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        try router.handle(Self.url("tuistapp://home/items/9"))
        try router.handle(Self.url("tuistapp://home/items/1"))

        router.markReady()

        #expect(router[path: .home] == detailPath)
    }

    @Test("해석할 수 없는 URL 은 상태를 바꾸지 않는다")
    func handle_unparsableURL_keepsState() throws {
        let router = Self.readyRouter()
        router[path: .home] = detailPath

        try router.handle(Self.url("tuistapp://nope"))

        #expect(router[path: .home] == detailPath)
    }

    @Test("방식별 모달 바인딩은 그 방식의 모달만 돌려준다")
    func presentedSubscript_otherStyle_returnsNil() {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        router.presented = PresentedRoute(root: .home(.detail(id: "1")), style: .fullScreenCover)

        #expect(router[presented: .sheet] == nil)
    }

    @Test("다른 방식의 바인딩이 nil 을 써도 떠 있는 모달은 닫히지 않는다")
    func presentedSubscript_setNilForOtherStyle_keepsPresented() {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        router.presented = PresentedRoute(root: .home(.detail(id: "1")), style: .fullScreenCover)

        router[presented: .sheet] = nil

        #expect(router.presented != nil)
    }

    @Test("같은 방식의 바인딩이 nil 을 쓰면 모달이 닫힌다")
    func presentedSubscript_setNilForSameStyle_clearsPresented() {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        router.presented = PresentedRoute(root: .home(.detail(id: "1")), style: .sheet)

        router[presented: .sheet] = nil

        #expect(router.presented == nil)
    }

    @Test("방식별 모달 바인딩에 값을 쓰면 그 모달이 뜬다")
    func presentedSubscript_setValue_setsPresented() throws {
        let router = AppRouter(gate: AllowAllDeepLinkGate())

        router[presented: .sheet] = PresentedRoute(root: .home(.detail(id: "1")), style: .sheet)

        let presented = try #require(router.presented)
        #expect(presented.root == .home(.detail(id: "1")))
    }

    @Test("다른 모달의 스택은 지금 모달의 경로를 읽지 않는다")
    func presentedPathSubscript_otherModalID_returnsEmpty() {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        let closing = PresentedRoute(root: .home(.detail(id: "A")), style: .sheet)
        router.presented = PresentedRoute(root: .home(.detail(id: "B")), style: .sheet, path: detailPath)

        #expect(router[presentedPath: closing.id].isEmpty)
    }

    @Test("닫히는 모달의 스택이 경로를 써도 지금 모달의 경로는 그대로다")
    func presentedPathSubscript_setForOtherModalID_keepsCurrentPath() throws {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        let closing = PresentedRoute(root: .home(.detail(id: "A")), style: .sheet)
        router.presented = PresentedRoute(root: .home(.detail(id: "B")), style: .sheet, path: detailPath)

        router[presentedPath: closing.id] = []

        #expect(try #require(router.presented).path == detailPath)
    }

    private static func readyRouter() -> AppRouter {
        let router = AppRouter(gate: AllowAllDeepLinkGate())
        router.markReady()
        return router
    }

    private static func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }
}

/// 테스트 중에 허용 여부를 바꿀 수 있는 게이트.
@MainActor
private final class ToggleGate: DeepLinkGate {
    var isOpen: Bool

    init(isOpen: Bool) {
        self.isOpen = isOpen
    }

    func canOpen(_: DeepLink) -> Bool {
        isOpen
    }
}
