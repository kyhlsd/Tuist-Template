//
//  AppExtension.swift
//  ProjectDescriptionHelpers
//

import ProjectDescription

/// 앱에 포함할 앱 익스텐션. `Project.app(extensions:)` 에 넘긴다.
///
/// 소스는 `App/Extensions/<name>/Sources/` 에 둔다. 번들 ID 는 앱 번들 ID 뒤에 이름 소문자를 붙인다
/// (`com.example.myapp.dev.notificationservice`). 앱과 같은 xcconfig 를 쓰므로 환경별 접미사·버전·서명이 앱을 따라간다.
///
/// 앱과 데이터를 나눌 코드는 익스텐션에 복사하지 말고 Core 모듈로 두고 양쪽이 의존한다(예: `Push`).
/// 앱과 같은 규칙으로 `*Testing` 에는 의존할 수 없다.
public struct AppExtension {
    let name: String
    let extensionAttributes: [String: Plist.Value]
    let dependencies: [TargetDependency]
    let entitlements: Entitlements?

    /// 알림을 표시하기 전에 내용을 바꾸는 익스텐션(이미지 첨부, 복호화 등).
    ///
    /// 주 클래스는 `name` 과 같은 이름의 `UNNotificationServiceExtension` 하위 클래스다.
    /// 알림 payload 에 `mutable-content: 1` 이 있어야 불린다.
    public static func notificationService(
        name: String = "NotificationService",
        dependencies: [TargetDependency] = []
    ) -> AppExtension {
        AppExtension(
            name: name,
            extensionAttributes: [
                "NSExtensionPointIdentifier": "com.apple.usernotifications.service",
                "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).\(name)"),
            ],
            dependencies: dependencies,
            entitlements: nil
        )
    }

    /// WidgetKit 위젯. 진입점은 `@main` 을 붙인 `WidgetBundle` 이다.
    ///
    /// 앱과 데이터를 나누려면 양쪽 `entitlements` 에 같은 App Group
    /// (`com.apple.security.application-groups`)을 넣는다.
    public static func widget(
        name: String = "Widget",
        dependencies: [TargetDependency] = [],
        entitlements: Entitlements? = nil
    ) -> AppExtension {
        AppExtension(
            name: name,
            extensionAttributes: [
                "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
            ],
            dependencies: dependencies,
            entitlements: entitlements
        )
    }
}

extension AppExtension {
    /// 익스텐션 타깃. `appName` 은 이 익스텐션을 포함하는 앱 타깃 이름이다.
    func target(appName: String) -> Target {
        .target(
            name: name,
            destinations: AppConstants.destinations,
            product: .appExtension,
            bundleId: "\(AppConstants.bundleID(for: appName))$(BUNDLE_ID_SUFFIX).\(name.lowercased())",
            deploymentTargets: AppConstants.deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": .string(name),
                // 앱과 다르면 업로드 때 경고가 난다. 같은 xcconfig 에서 오므로 항상 같다.
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "NSExtension": .dictionary(extensionAttributes),
            ]),
            sources: ["Extensions/\(name)/Sources/**"],
            entitlements: entitlements,
            dependencies: dependencies
        )
    }
}
