// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings
    import struct ProjectDescription.Settings

    let packageSettings = PackageSettings(
        productTypes: [:],
        // 외부 패키지 프로젝트에도 앱과 같은 구성 이름을 둔다. 없으면 Staging 으로 빌드할 때
        // 패키지는 기본 구성으로 빌드되어 최적화·dSYM 설정이 앱과 어긋난다.
        // 이름과 변형(debug/release)은 Settings+Common.swift 의 `common` 과 맞춘다.
        baseSettings: .settings(configurations: [
            .debug(name: "Debug"),
            .release(name: "Staging"),
            .release(name: "Release"),
        ])
    )
#endif

let package = Package(
    name: "TuistApp",
    dependencies: [
        // Networking 의 OpenAPI 생성 클라이언트가 쓰는 런타임.
        // 생성기(CLI)는 여기가 아니라 mise.toml 에 고정한다.
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.12.1"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.8.0"),
        // App 의 크래시 리포팅과 비치명 에러 전송(Crashlytics). App 타깃만 의존한다.
        // 12.11.0 미만은 초기화 직후 호출이 조용히 버려지는 버그가 있다. 13 은 따로 검토한다.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.19.2"),
    ]
)
