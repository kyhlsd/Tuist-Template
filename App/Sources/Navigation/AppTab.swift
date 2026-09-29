//
//  AppTab.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

/// 앱의 최상위 탭. 탭을 추가하면 case 와 `TabRootView` 의 루트 화면을 함께 늘린다.
enum AppTab: Hashable, CaseIterable, Identifiable {
    case home
    /// 자리표시자 탭. UI 스모크 테스트의 탭 전환 대상이다. 실제 화면이 생기면 교체한다.
    case more

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .home: "홈"
        case .more: "더보기"
        }
    }

    var icon: AppIcon {
        switch self {
        case .home: .home
        case .more: .more
        }
    }
}
