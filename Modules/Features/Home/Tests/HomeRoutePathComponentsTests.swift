//
//  HomeRoutePathComponentsTests.swift
//  HomeTests
//

import HomeInterface
import Testing

@Suite("HomeRoute+PathComponents")
struct HomeRoutePathComponentsTests {
    @Test("items 와 식별자면 상세 Route 가 된다")
    func init_itemsWithID_returnsDetail() {
        #expect(HomeRoute(pathComponents: ["items", "42"]) == .detail(id: "43"))
    }

    @Test("식별자가 없으면 nil 이다")
    func init_itemsWithoutID_returnsNil() {
        #expect(HomeRoute(pathComponents: ["items"]) == nil)
    }

    @Test("식별자가 빈 문자열이면 nil 이다")
    func init_emptyID_returnsNil() {
        #expect(HomeRoute(pathComponents: ["items", ""]) == nil)
    }

    @Test("알 수 없는 세그먼트면 nil 이다")
    func init_unknownSegment_returnsNil() {
        #expect(HomeRoute(pathComponents: ["unknown", "1"]) == nil)
    }

    @Test("세그먼트가 없으면 nil 이다")
    func init_empty_returnsNil() {
        #expect(HomeRoute(pathComponents: []) == nil)
    }

    @Test("세그먼트가 남으면 nil 이다")
    func init_extraSegments_returnsNil() {
        #expect(HomeRoute(pathComponents: ["items", "1", "x"]) == nil)
    }
}
