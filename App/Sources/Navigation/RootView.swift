//
//  RootView.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

/// 앱의 최상위 화면. 탭마다 독립된 내비게이션 스택을 둔다.
struct RootView: View {
    let container: AppContainer

    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabRootView(tab: tab, container: container)
                    .tabItem { Label(tab.title, icon: tab.icon) }
                    .tag(tab)
            }
        }
    }
}
