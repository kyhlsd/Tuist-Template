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
}

private enum TestRoute: Hashable {
    case first
    case second
}
