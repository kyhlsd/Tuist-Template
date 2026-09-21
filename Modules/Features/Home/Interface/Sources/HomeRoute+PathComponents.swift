//
//  HomeRoute+PathComponents.swift
//  HomeInterface
//

public extension HomeRoute {
    /// 딥링크 경로 세그먼트로 Route 를 만든다.
    ///
    /// URL 형식은 이 피처가 소유한다. 탭 세그먼트(`home`)는 App 이 이미 소비했으므로
    /// 이 피처 몫의 세그먼트만 들어온다. 외부 입력이므로 알 수 없는 형식이면 `nil` 이다.
    ///
    ///     ["items", "42"] → .detail(id: "42")
    init?(pathComponents: [String]) {
        guard pathComponents.first == PathComponent.items else { return nil }
        let rest = pathComponents.dropFirst()
        guard rest.count == 1, let id = rest.first, !id.isEmpty else { return nil }
        self = .detail(id: id)
    }
}

private enum PathComponent {
    static let items = "items"
}
