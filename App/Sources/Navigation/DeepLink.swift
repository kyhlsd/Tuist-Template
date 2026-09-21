//
//  DeepLink.swift
//  TuistApp
//

/// 딥링크·푸시가 가리키는 목적지. 어느 탭의 스택을 무엇으로 바꿀지만 담는다.
///
/// 모달 목적지가 필요해지면 필드를 추가한다.
struct DeepLink: Equatable {
    let tab: AppTab
    /// 탭 스택을 이 값으로 교체한다. 비어 있으면 탭 루트다.
    let path: [AppRoute]
}
