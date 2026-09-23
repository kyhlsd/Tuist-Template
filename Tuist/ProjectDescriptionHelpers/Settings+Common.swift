//
//  Settings+Common.swift
//  ProjectDescriptionHelpers
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription

public extension Settings {
    /// 모든 모듈이 공유하는 빌드 설정.
    ///
    /// `base` 에는 환경과 무관하게 항상 같은 값만 둔다.
    /// 환경별로 갈리는 값은 xcconfig 에 있으며, 같은 키를 양쪽에 두지 않는다.
    /// (중복되면 base 가 이겨서 xcconfig 쪽이 조용히 무시된다.)
    ///
    /// SWIFT_VERSION 6.0 은 언어 모드 6 을 켠다. 이 모드에서는 동시성 검사가
    /// 이미 에러로 강제되므로 SWIFT_STRICT_CONCURRENCY 를 따로 지정하지 않는다.
    ///
    /// APP_NAME 은 xcconfig 가 `$(APP_NAME)` 으로 참조한다. (APP_DISPLAY_NAME 등)
    /// 이름의 원본은 `AppConstants.appName` 한 곳이다.
    static let common: Settings = .settings(
        base: [
            "APP_NAME": .string(AppConstants.appName),
            "SWIFT_VERSION": "6.0",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
            "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        ],
        configurations: [
            .debug(
                name: "Debug",
                xcconfig: .relativeToRoot("Configurations/Debug.xcconfig")
            ),
            .release(
                name: "Release",
                xcconfig: .relativeToRoot("Configurations/Release.xcconfig")
            ),
        ]
    )

    /// 기본 액터 격리를 MainActor 로 켠 공통 설정.
    ///
    /// 선언마다 `@MainActor` 를 붙이지 않아도 모듈 전체가 메인 액터에 격리된다.
    /// 화면만 다루는 모듈(DesignSystem)용이다. Domain·Data 처럼 백그라운드에서
    /// 도는 코드가 있는 모듈에 켜면 불필요한 메인 스레드 hop 이 생기므로 쓰지 않는다.
    static var mainActorByDefault: Settings {
        var settings = common
        settings.base["SWIFT_DEFAULT_ACTOR_ISOLATION"] = "MainActor"
        return settings
    }
}

public extension InfoPlist {
    /// 실행 가능한 타깃(앱, 데모 앱)이 공유하는 Info.plist.
    ///
    /// xcconfig 값은 여기를 거쳐야 코드에서 읽을 수 있다.
    /// 데모 앱도 같은 키가 필요하므로 public 으로 열어둔다.
    ///
    /// - Parameter displayName: 홈 화면에 보이는 이름. 앱은 xcconfig 의 APP_DISPLAY_NAME 을,
    ///   데모 앱은 "HomeDemo" 처럼 자기 이름을 쓴다. 같은 이름이면 기기에서 구분할 수 없다.
    /// - Parameter urlSchemes: 딥링크로 받을 커스텀 URL 스킴. 비어 있으면 `CFBundleURLTypes` 를 넣지 않는다.
    ///   앱만 넘긴다. 데모 앱까지 같은 스킴을 등록하면 어느 앱이 링크를 받을지 알 수 없다.
    /// - Parameter additionalEntries: 이 타깃에만 넣을 키. 공통 키와 겹치면 이 값이 이긴다.
    static func runnable(
        displayName: String = "$(APP_DISPLAY_NAME)",
        urlSchemes: [String] = [],
        additionalEntries: [String: Plist.Value] = [:]
    ) -> InfoPlist {
        var plist: [String: Plist.Value] = [
            "CFBundleDisplayName": .string(displayName),
            "CFBundleShortVersionString": "$(MARKETING_VERSION)",
            "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
            "API_BASE_URL": "$(API_BASE_URL)",
            "LOG_LEVEL": "$(LOG_LEVEL)",
            "ANALYTICS_APP_KEY": "$(ANALYTICS_APP_KEY)",
            "MAP_SDK_KEY": "$(MAP_SDK_KEY)",
            "UILaunchScreen": [:],
        ]
        if !urlSchemes.isEmpty {
            plist["CFBundleURLTypes"] = [
                [
                    "CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                    "CFBundleURLSchemes": .array(urlSchemes.map { .string($0) }),
                ],
            ]
        }
        plist.merge(additionalEntries) { _, additional in additional }
        return .extendingDefault(with: plist)
    }
}
