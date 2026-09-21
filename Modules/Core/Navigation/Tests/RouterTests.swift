//
//  RouterTests.swift
//  NavigationTests
//

import Navigation
import Testing

@Suite("Router")
struct RouterTests {
    @Test("push 하면 경로가 한 단계 깊어진다")
    func push_route_appendsToPath() {
        let router = Router()

        router.push(TestRoute.first)

        #expect(router.path.count == 1)
    }

    @Test("루트에서 pop 해도 아무 일도 일어나지 않는다")
    func pop_atRoot_keepsPathEmpty() {
        let router = Router()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test("popToRoot 는 쌓인 경로를 모두 비운다")
    func popToRoot_afterPushes_emptiesPath() {
        let router = Router()
        router.push(TestRoute.first)
        router.push(TestRoute.second)

        router.popToRoot()

        #expect(router.path.isEmpty)
    }

    @Test("present 하면 Route 와 방식을 기록한다")
    func present_route_recordsPresented() throws {
        let router = Router()

        router.present(TestRoute.first, style: .sheet)

        let presented = try #require(router.presented)
        #expect(presented.route == AnyHashable(TestRoute.first))
        #expect(presented.style == .sheet)
    }

    @Test("dismiss 하면 띄운 모달 기록이 사라진다")
    func dismiss_afterPresent_clearsPresented() {
        let router = Router()
        router.present(TestRoute.first, style: .fullScreenCover)

        router.dismiss()

        #expect(router.presented == nil)
    }
}

private enum TestRoute: Route {
    case first
    case second
}
