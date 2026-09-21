//
//  DeepLinkParser.swift
//  TuistApp
//

import Foundation
import HomeInterface

/// URL 을 `DeepLink` 로 바꾼다.
///
/// 커스텀 스킴(`tuistapp://home/items/42`)과 웹 URL(`https://example.com/home/items/42`)이
/// 같은 세그먼트 배열(`["home", "items", "42"]`)이 되므로 스킴과 무관하게 동작한다.
/// 첫 세그먼트로 탭을 고르고, 나머지는 그 피처 Interface 의 `init?(pathComponents:)` 에 맡긴다.
///
/// URL 은 외부 입력이다. 해석할 수 없으면 `nil` 을 돌려주고 호출부는 무시한다.
struct DeepLinkParser {
    func parse(_ url: URL) -> DeepLink? {
        let segments = Self.segments(of: url)
        guard let tabSegment = segments.first else { return nil }
        let rest = Array(segments.dropFirst())

        // 탭 세그먼트만 대소문자를 무시한다. 나머지(식별자 등)는 피처가 그대로 받는다.
        switch tabSegment.lowercased() {
        case TabSegment.home:
            if rest.isEmpty {
                return DeepLink(tab: .home, path: [])
            }
            guard let route = HomeRoute(pathComponents: rest) else { return nil }
            return DeepLink(tab: .home, path: [.home(route)])
        default:
            return nil
        }
    }

    /// 커스텀 스킴은 host 가 첫 세그먼트이고, 웹 URL 은 host 가 도메인이므로 경로만 쓴다.
    /// 쿼리와 프래그먼트는 쓰지 않는다.
    private static func segments(of url: URL) -> [String] {
        let path = url.pathComponents.filter { $0 != PathSeparator.root }
        let isWeb = url.scheme.map { WebScheme.all.contains($0.lowercased()) } ?? false
        if isWeb {
            return path
        }
        guard let host = url.host(), !host.isEmpty else { return path }
        return [host] + path
    }
}

private enum TabSegment {
    static let home = "home"
}

private enum WebScheme {
    static let all: Set<String> = ["http", "https"]
}

private enum PathSeparator {
    static let root = "/"
}
