//
//  DeepLinkGate.swift
//  TuistApp
//

/// 딥링크를 지금 열어도 되는지 판단한다.
///
/// 인증이 필요한 목적지가 생기면 로그인 상태를 보는 구현으로 바꾼다. 거부한 링크는
/// `AppRouter` 가 보류하므로, 로그인을 마친 뒤 `AppRouter.resumePending()` 을 부르면 이어서 열린다.
@MainActor
protocol DeepLinkGate {
    func canOpen(_ link: DeepLink) -> Bool
}

/// 모든 링크를 허용한다. 인증이 필요한 목적지가 아직 없다.
struct AllowAllDeepLinkGate: DeepLinkGate {
    func canOpen(_: DeepLink) -> Bool {
        true
    }
}
