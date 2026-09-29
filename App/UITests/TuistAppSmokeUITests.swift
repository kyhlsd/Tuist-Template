//
//  TuistAppSmokeUITests.swift
//  TuistAppUITests
//

import XCTest

/// 앱을 실제로 띄워 탭 전환과 딥링크가 이어지는지만 확인하는 스모크 테스트.
///
/// `UITestLaunchArgument.stubItems` 로 실행하므로 홈 목록은 네트워크 없이 고정 항목 하나를 보여준다.
/// 세부 분기는 유닛 테스트(`AppRouterTests`, `DeepLinkParserTests`)가 맡는다. 여기서는 조립이 E2E 로 통하는지만 본다.
@MainActor
final class TuistAppSmokeUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 탭은 한국어 라벨로 찾는다. 번역이 추가돼도 시뮬레이터 언어와 상관없이 같은 라벨이 나오도록 언어를 고정한다.
        app.launchArguments = [UITestLaunchArgument.stubItems] + Language.korean
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testSwitchingTabs_showsEachTabRoot() {
        app.tabBars.buttons[TabLabel.more].tap()
        XCTAssertTrue(morePlaceholder.waitForExistence(timeout: Timeout.element))

        app.tabBars.buttons[TabLabel.home].tap()
        XCTAssertTrue(stubItem.waitForExistence(timeout: Timeout.element))
    }

    func testDeepLinkToHome_selectsHomeTab() throws {
        app.tabBars.buttons[TabLabel.more].tap()
        XCTAssertTrue(morePlaceholder.waitForExistence(timeout: Timeout.element))

        try app.open(homeURL())

        XCTAssertTrue(stubItem.waitForExistence(timeout: Timeout.element))
    }

    private var morePlaceholder: XCUIElement {
        app.descendants(matching: .any)[UITestLaunchArgument.morePlaceholderIdentifier]
    }

    private var stubItem: XCUIElement {
        app.staticTexts[UITestLaunchArgument.stubItemTitle]
    }

    /// 스킴은 `AppConstants.urlScheme` 이 이 타깃 Info.plist 로 넘어온 값이다(`Target.uiTestTarget`).
    private func homeURL() throws -> URL {
        let scheme = try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: InfoKey.appURLScheme) as? String,
            "UI 테스트 타깃 Info.plist 에 \(InfoKey.appURLScheme) 이 없습니다."
        )
        return try XCTUnwrap(URL(string: "\(scheme)://\(DeepLinkPath.home)"))
    }
}

private enum TabLabel {
    static let home = "홈"
    static let more = "더보기"
}

private enum Language {
    static let korean = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
}

private enum InfoKey {
    static let appURLScheme = "APP_URL_SCHEME"
}

private enum DeepLinkPath {
    static let home = "home"
}

private enum Timeout {
    static let element: TimeInterval = 10
}
