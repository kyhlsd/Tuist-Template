//
//  TuistAppTests.swift
//  TuistAppTests
//

import Foundation
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

    /// `AppConstants.urlScheme` → `InfoPlist.runnable(urlSchemes:)` → `CFBundleURLTypes` 연결을 확인한다.
    /// 끊기면 딥링크 URL 을 열어도 앱이 실행되지 않는다.
    @Test("Info.plist 에 커스텀 URL 스킴이 등록돼 있다")
    func infoPlist_urlTypes_registersScheme() throws {
        let urlTypes = try #require(
            Bundle.main.object(forInfoDictionaryKey: InfoKey.urlTypes) as? [[String: Any]]
        )
        let schemes = urlTypes.flatMap { $0[InfoKey.urlSchemes] as? [String] ?? [] }

        #expect(schemes.contains { !$0.isEmpty })
    }

    private enum InfoKey {
        static let urlTypes = "CFBundleURLTypes"
        static let urlSchemes = "CFBundleURLSchemes"
    }
}
