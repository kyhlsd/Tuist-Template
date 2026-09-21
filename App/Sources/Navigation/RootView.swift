//
//  RootView.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

/// 앱의 최상위 화면. 탭마다 독립된 내비게이션 스택을 두고, 라우터가 띄운 모달 한 단계를 표시한다.
///
/// 상태는 모두 `AppRouter` 에 있고 여기서는 바인딩만 한다.
struct RootView: View {
    let container: AppContainer
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabRootView(tab: tab, container: container, router: router)
                    .tabItem { Label(tab.title, icon: tab.icon) }
                    .tag(tab)
            }
        }
        .sheet(item: $router[presented: .sheet]) { presented in
            modal(presented)
        }
        .fullScreenCover(item: $router[presented: .fullScreenCover]) { presented in
            modal(presented)
        }
        .onAppear { router.markReady() }
    }

    /// 모달은 자기 스택을 가진다. 모달 안에서도 앱의 모든 Route 로 이동할 수 있다.
    /// 모달 안의 화면은 그 모달에 묶인 라우터를 받으므로 push 가 모달 뒤의 탭 스택이나 다음 모달로 가지 않는다.
    private func modal(_ presented: PresentedRoute) -> some View {
        let modalRouter = router.router(forPresented: presented.id)
        return NavigationStack(path: $router[presentedPath: presented.id]) {
            container.makeView(for: presented.root, router: modalRouter)
                .appDestinations(container, router: modalRouter)
        }
    }
}
