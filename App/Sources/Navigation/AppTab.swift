//
//  AppTab.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

/// 앱의 최상위 탭. 탭을 추가하면 case 와 `TabRootView` 의 루트 화면을 함께 늘린다.
enum AppTab: Hashable, CaseIterable, Identifiable {
    case home

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .home: "홈"
        }
    }

    var icon: AppIcon {
        switch self {
        case .home: .home
        }
    }
}
