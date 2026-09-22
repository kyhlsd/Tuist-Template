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
    ]
)
