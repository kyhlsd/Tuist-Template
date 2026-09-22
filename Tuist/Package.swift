// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [:]
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
