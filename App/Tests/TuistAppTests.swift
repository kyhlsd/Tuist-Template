//
//  TuistAppTests.swift
//  TuistAppTests
//

import Testing
@testable import TuistApp

@Suite("앱 설정")
struct TuistAppTests {
    /// xcconfig → Info.plist(`InfoPlist.runnable`) → `AppConfiguration` 연결이 끊기지 않았는지 확인한다.
    /// 끊기면 앱은 시작하자마자 preconditionFailure 로 멈춘다.
    @Test("Info.plist 에서 API 기본 URL 을 읽는다")
    func fromMainBundle_infoPlist_readsAPIBaseURL() {
        let configuration = AppConfiguration.fromMainBundle()

        #expect(configuration.apiBaseURL.host() != nil)
    }
}
