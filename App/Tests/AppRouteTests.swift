//
//  AppRouteTests.swift
//  TuistAppTests
//

import HomeInterface
import Navigation
import Testing
@testable import TuistApp

@Suite("AppRoute")
struct AppRouteTests {
    @Test("HomeRoute 는 home 으로 감싼다")
    func init_homeRoute_wrapsAsHome() {
        #expect(AppRoute(HomeRoute.detail(id: "1")) == .home(.detail(id: "1")))
    }

    @Test("앱이 모르는 Route 면 nil 이다")
    func init_unknownRoute_returnsNil() {
        #expect(AppRoute(UnknownRoute.somewhere) == nil)
    }
}

private enum UnknownRoute: Route {
    case somewhere
}
