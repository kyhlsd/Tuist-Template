//
//  InteractionCatalog.swift
//  DesignSystemDemo
//
//  비동기 버튼·누름 반응·포커스·적응형 스택·비활성.
//

import DesignSystem
import SwiftUI

struct InteractionCatalog: View {
    private enum Layout {
        /// 비동기 버튼의 진행 표시를 볼 수 있을 만큼의 가짜 작업 시간.
        static let simulatedWork: Duration = .seconds(2)
        /// 넓은 목록 행은 조금만 줄여야 자연스럽다.
        static let rowPressedScale: CGFloat = 0.99
    }

    @Environment(\.theme) private var theme

    @State private var savedCount = 0
    @State private var text = ""
    @State private var isSectionDisabled = false
    @FocusState private var focusedField: Bool

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "AsyncButton") {
                VStack(spacing: theme.metrics.spacing.md) {
                    AsyncButton("저장하기") {
                        // 데모용 대기다. 화면을 벗어나 취소되면 그대로 끝내면 되므로 에러는 무시한다.
                        try? await Task.sleep(for: Layout.simulatedWork)
                        savedCount += 1
                    }
                    .buttonStyle(.appPrimary)

                    AsyncButton(
                        "동기화",
                        icon: .refresh,
                        progress: .besideLabel,
                        progressTint: \.textPrimary
                    ) {
                        // 데모용 대기다. 화면을 벗어나 취소되면 그대로 끝내면 되므로 에러는 무시한다.
                        try? await Task.sleep(for: Layout.simulatedWork)
                    }
                    .buttonStyle(.appSecondary)

                    Text("완료 횟수: \(savedCount)")
                        .appText(\.bodySmall, color: \.textSecondary)
                }
            }

            CatalogSection(title: "Pressable") {
                VStack(spacing: theme.metrics.spacing.md) {
                    VStack(alignment: .leading, spacing: theme.metrics.spacing.xs) {
                        Text("눌러 보세요")
                            .appText(\.titleSmall, color: \.textPrimary)
                        Text("카드 전체가 하나의 버튼으로 동작합니다.")
                            .appText(\.bodySmall, color: \.textSecondary)
                    }
                    .appCard()
                    .appPressable {}

                    AppListRow(icon: .person, title: "프로필", subtitle: "이름, 사진")
                        .appPressable(scale: Layout.rowPressedScale, highlightRadius: \.md) {}
                }
            }

            CatalogSection(title: "Icon Button") {
                HStack(spacing: theme.metrics.spacing.lg) {
                    AppIconButton(icon: .share, accessibilityLabel: "공유") {}
                    AppIconButton(icon: .bookmark, accessibilityLabel: "저장") {}
                    AppIconButton(
                        icon: .delete,
                        accessibilityLabel: "삭제",
                        tint: \.danger
                    ) {}
                }
            }

            CatalogSection(title: "Focus Ring") {
                VStack(spacing: theme.metrics.spacing.md) {
                    TextField("탭하면 링이 나타납니다", text: $text)
                        .appText(\.bodyLarge, color: \.textPrimary)
                        .padding(theme.metrics.spacing.md)
                        .background(
                            theme.colors.surface,
                            in: RoundedRectangle(
                                cornerRadius: theme.metrics.radius.md,
                                style: .continuous
                            )
                        )
                        .focused($focusedField)
                        .appFocusRing(focusedField)
                }
            }

            CatalogSection(title: "Adaptive Stack") {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                    Text("접근성 확대 시 세로로 전환됩니다")
                        .appText(\.caption, color: \.textTertiary)

                    AppAdaptiveStack(spacing: theme.metrics.spacing.md) {
                        Image(.calendar)
                            .appIcon(\.md)
                            .foregroundStyle(theme.colors.accent)
                            .accessibilityHidden(true)
                        Text("2026년 8월 19일 수요일 오후 3시")
                            .appText(\.bodyMedium, color: \.textPrimary)
                        AppBadge(text: "예정", style: .accent)
                    }
                }
            }

            CatalogSection(title: "Disabled") {
                VStack(spacing: theme.metrics.spacing.md) {
                    Toggle("비활성화", isOn: $isSectionDisabled)
                        .toggleStyle(.appSwitch)

                    AppDivider()

                    VStack(spacing: theme.metrics.spacing.sm) {
                        Button("액션") {}
                            .buttonStyle(.appSecondary)
                        AppChip(text: "필터", isSelected: true) {}
                    }
                    .appDisabled(isSectionDisabled)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Interaction") {
    InteractionCatalog()
        .theme(.standard)
}

#Preview("Interaction / Accessibility XXL") {
    InteractionCatalog()
        .theme(.standard)
        .environment(\.dynamicTypeSize, .accessibility2)
}
