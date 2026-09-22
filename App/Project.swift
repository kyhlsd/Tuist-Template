//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 앱은 조립만 한다. (App/Sources/DI: 의존성, App/Sources/Navigation: 탭·Route → 화면)
/// 피처는 구현과 Interface 를 모두 연결한다. 구현은 루트 화면을, Interface 는 Route 를 제공한다.
let project = Project.app(
    name: AppConstants.appName,
    dependencies: [
        .module(.feature("Home")),
        .module(.featureInterface("Home")),
        .module(.data),
        .module(.domain),
        .module(.networking),
        .module(.designSystem),
        .module(.navigation),
        .module(.diagnostics),
        // Crashlytics 전송 어댑터(App/Sources/Diagnostics)만 쓴다. 모듈은 Firebase 를 모른다.
        .external(name: "FirebaseCrashlytics"),
        .external(name: "FirebaseCore"),
    ],
    targetSettings: [
        // Firebase 정적 라이브러리의 Objective-C 카테고리를 링크한다.
        "OTHER_LDFLAGS": "$(inherited) -ObjC",
        // dSYM 업로드 스크립트가 Tuist/.build/checkouts 의 SDK 스크립트를 읽는다.
        "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    ],
    scripts: [
        // Release 이고 GoogleService-Info.plist 가 있을 때만 올린다. 아니면 경고만 남긴다.
        .post(
            path: .relativeToRoot("Scripts/crashlytics-upload-symbols.sh"),
            name: "Upload Crashlytics dSYM",
            inputFileListPaths: [
                .relativeToRoot("Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/CrashlyticsInputFiles.xcfilelist"),
            ],
            basedOnDependencyAnalysis: false
        ),
    ]
)
