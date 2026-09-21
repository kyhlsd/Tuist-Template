//
//  AppConstants.swift
//  ProjectDescriptionHelpers
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription

/// 프로젝트 전역에서 공유하는 값.
///
/// 환경(Debug/Release)에 따라 달라지지 않는 것만 여기에 둔다.
/// 환경마다 갈리는 값은 Configurations/*.xcconfig 로 간다.
public enum AppConstants {
    /// 앱 이름. 템플릿으로 새 프로젝트를 만들 때 여기만 바꾸면 된다.
    ///
    /// 앱 타깃·워크스페이스 이름과 빌드 설정 APP_NAME 이 모두 이 값에서 나온다.
    /// 워크스페이스 스킴은 "\(appName)-Workspace" 가 되므로
    /// `.claude/scripts/xcbuild.sh` 의 SCHEME 도 함께 바꾼다.
    public static let appName = "TuistApp"
    public static let bundleIDPrefix = "com.olivebridge"
    public static let organizationName = "Olive Bridge"
    public static let deploymentTargets: DeploymentTargets = .iOS("17.0")
    public static let destinations: Destinations = .iOS
    /// 앱의 커스텀 URL 스킴(`tuistapp://home/items/42`). 템플릿으로 새 앱을 만들면 바꾼다.
    ///
    /// 앱 타깃의 Info.plist(`CFBundleURLTypes`)에만 등록한다. 데모 앱은 등록하지 않는다.
    /// 앱 코드는 스킴을 비교하지 않으므로 여기만 바꾸면 된다.
    public static let urlScheme = "tuistapp"

    /// 모듈 이름으로 번들 ID 를 만든다.
    public static func bundleID(for name: String) -> String {
        "\(bundleIDPrefix).\(name.lowercased())"
    }
}
