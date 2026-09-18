//
//  DesignSystemCatalog.swift
//  DesignSystemDemo
//
//  카탈로그 첫 화면. 페이지 목록과 전역 상태 배너 토글.
//
//  토큰·컴포넌트 변경 시 회귀를 눈으로 확인하기 위한 카탈로그다.
//  DesignSystemDemo 타깃에만 들어가므로 앱 본체에는 포함되지 않는다.
//  DesignSystem 의 public API 만 쓴다. 여기서 컴파일되지 않는 컴포넌트는
//  다른 모듈에서도 쓸 수 없다는 뜻이므로, internal 을 열기 전에 API 누락인지 따진다.
//  각 페이지는 Catalog/Pages/ 에 있다.
//

import DesignSystem
import SwiftUI

struct DesignSystemCatalog: View {
    @Environment(\.theme) private var theme

    /// 전역 상태 배너 데모용. 실제 앱에서는 네트워크 모니터 등이 이 값을 소유한다.
    @State private var isOffline = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(CatalogPage.allCases) { page in
                    NavigationLink(value: page) {
                        Label(page.title, icon: page.icon)
                            .labelStyle(.appTinted)
                    }
                }

                Toggle("오프라인 상태 배너", isOn: $isOffline)
                    .toggleStyle(.appSwitch)
            }
            .navigationTitle("Design System")
            .navigationDestination(for: CatalogPage.self) { page in
                page.destination
                    .navigationTitle(page.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        // NavigationStack 바깥이므로 배너가 내비게이션 바 위에 얹힌다.
        .appStatusBanner(
            isPresented: isOffline,
            title: "오프라인 상태입니다",
            placement: .aboveNavigationBar
        )
    }
}

// MARK: - Previews

#Preview("Catalog") {
    DesignSystemCatalog()
        .theme(.standard)
}
