//
//  StatusCatalog.swift
//  DesignSystemDemo
//
//  빈 화면·오류·오프라인·로딩.
//

import DesignSystem
import SwiftUI

struct StatusCatalog: View {
    private enum Layout {
        /// 전면 상태 화면을 카드 안에 담아 보여 주기 위한 높이.
        static let statusScreenHeight: CGFloat = 320
        static let loadingHeight: CGFloat = 160
    }

    @Environment(\.theme) private var theme
    @State private var isLoading = false

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "Empty") {
                AppStatusView.empty(
                    title: "아직 항목이 없습니다",
                    message: "오른쪽 위 + 버튼으로 첫 항목을 추가해 보세요.",
                    action: AppStatusAction(title: "항목 추가") {}
                )
                .frame(height: Layout.statusScreenHeight)
            }

            CatalogSection(title: "Error") {
                AppStatusView.error(
                    message: "일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.",
                    retry: {}
                )
                .frame(height: Layout.statusScreenHeight)
            }

            CatalogSection(title: "Offline") {
                AppStatusView.offline(retry: {})
                    .frame(height: Layout.statusScreenHeight)
            }

            CatalogSection(title: "Loading") {
                VStack(spacing: theme.metrics.spacing.lg) {
                    AppLoadingView(message: "불러오는 중")
                        .frame(height: Layout.loadingHeight)
                    Button(isLoading ? "오버레이 끄기" : "오버레이 켜기") {
                        isLoading.toggle()
                    }
                    .buttonStyle(.appSecondary)
                }
            }
        }
        .appLoadingOverlay(isLoading, message: "처리 중")
    }
}

// MARK: - Previews

#Preview("Status") {
    StatusCatalog()
        .theme(.standard)
}
