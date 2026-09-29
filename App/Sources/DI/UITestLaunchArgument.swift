//
//  UITestLaunchArgument.swift
//  TuistApp
//

/// 앱과 UI 테스트(`TuistAppUITests`)가 함께 쓰는 약속.
///
/// UI 테스트는 앱을 import 할 수 없으므로 이 파일을 두 타깃이 각자 컴파일한다(`Project.app` 참고).
/// 값만 두고 동작은 두지 않는다. 앱 쪽 동작은 DEBUG 에서만 켜진다(`AppContainer.makeItemRepository`).
enum UITestLaunchArgument {
    /// 이 인자로 실행하면 항목 저장소가 네트워크 대신 `UITestItemRepository` 를 쓴다.
    static let stubItems = "-UITestStubItems"
    /// `UITestItemRepository` 가 돌려주는 항목의 제목. UI 테스트가 이 텍스트로 홈 목록을 확인한다.
    static let stubItemTitle = "UI 테스트 항목"
    /// 자리표시자 탭(`AppTab.more`) 루트 화면의 접근성 식별자.
    static let morePlaceholderIdentifier = "more.placeholder"
}
