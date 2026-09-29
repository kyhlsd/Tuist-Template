//
//  UITestItemRepository.swift
//  TuistApp
//

#if DEBUG
    import Domain

    /// UI 테스트가 네트워크 없이 홈 목록을 확인하도록 항목 하나를 돌려주는 저장소.
    ///
    /// 앱은 `*Testing` 모듈에 의존할 수 없으므로 DomainTesting 의 `StubItemRepository` 대신 여기 둔다.
    /// Release 에는 들어가지 않는다. `UITestLaunchArgument.stubItems` 로 실행할 때만 쓴다.
    struct UITestItemRepository: ItemRepository {
        func fetchItems() async throws(ItemError) -> [Item] {
            [Item(id: StubItem.id, title: UITestLaunchArgument.stubItemTitle)]
        }
    }

    private enum StubItem {
        static let id = "ui-test-1"
    }
#endif
