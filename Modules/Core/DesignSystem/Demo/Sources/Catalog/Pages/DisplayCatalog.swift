//
//  DisplayCatalog.swift
//  DesignSystemDemo
//
//  배지·목록 행·섹션 헤더·진행률·스켈레톤.
//

import DesignSystem
import SwiftUI

struct DisplayCatalog: View {
    private enum Layout {
        static let sampleProgress: Double = 0.65
        static let skeletonLineHeight: CGFloat = 20
        static let skeletonShortLineWidth: CGFloat = 200
        static let skeletonBlockHeight: CGFloat = 80
    }

    @Environment(\.theme) private var theme

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "Badge") {
                HStack(spacing: theme.metrics.spacing.sm) {
                    AppBadge(text: "기본")
                    AppBadge(text: "강조", style: .accent)
                    AppBadge(text: "완료", style: .success, icon: .success)
                    AppBadge(text: "주의", style: .warning)
                    AppBadge(text: "오류", style: .danger)
                }
            }

            CatalogSection(title: "List Row") {
                VStack(spacing: 0) {
                    AppListRow(icon: .person, title: "계정", subtitle: "프로필과 로그인 정보")
                    AppDivider(inset: \.xxxl)
                    AppListRow(icon: .bell, title: "알림") {
                        AppRowDetail(text: "켬")
                    }
                    AppDivider(inset: \.xxxl)
                    AppListRow(icon: .lock, iconTint: \.danger, title: "개인정보 보호")
                }
            }

            CatalogSection(title: "Section Header") {
                AppSectionHeader(title: "최근 항목", subtitle: "지난 7일") {
                    Button("전체 보기") {}
                        .buttonStyle(.appTextButton)
                }
            }

            CatalogSection(title: "Progress") {
                VStack(spacing: theme.metrics.spacing.lg) {
                    ProgressView("업로드 중", value: Layout.sampleProgress)
                        .progressViewStyle(.appLinear(showsPercentage: true))
                    ProgressView()
                        .progressViewStyle(.appLinear)
                }
            }

            CatalogSection(title: "Skeleton") {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                    AppSkeleton(height: Layout.skeletonLineHeight)
                    AppSkeleton(height: Layout.skeletonLineHeight)
                        .frame(maxWidth: Layout.skeletonShortLineWidth)
                    AppSkeleton(height: Layout.skeletonBlockHeight, cornerRadius: \.md)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Display") {
    DisplayCatalog()
        .theme(.standard)
}
