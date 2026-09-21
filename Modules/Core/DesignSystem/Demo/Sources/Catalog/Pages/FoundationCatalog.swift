//
//  FoundationCatalog.swift
//  DesignSystemDemo
//
//  토큰(타이포그래피·색·여백·대비·아이콘).
//

import DesignSystem
import SwiftUI

struct FoundationCatalog: View {
    private enum Layout {
        static let swatchMinWidth: CGFloat = 96
        static let swatchHeight: CGFloat = 48
        static let spacingLabelWidth: CGFloat = 40
        static let spacingBarHeight: CGFloat = 16
        static let iconCellMinWidth: CGFloat = 64
        /// 긴 아이콘 이름이 칸을 넘지 않게 줄이는 하한.
        static let iconNameMinScale: CGFloat = 0.7
    }

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "Typography") {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.md) {
                    ForEach(Self.fontSamples, id: \.name) { sample in
                        VStack(alignment: .leading, spacing: theme.metrics.spacing.xxs) {
                            Text(sample.name)
                                .appText(\.caption, color: \.textTertiary)
                            Text("다람쥐 헌 쳇바퀴에 타고파 Aa 123")
                                .appText(sample.keyPath, color: \.textPrimary)
                        }
                    }
                }
            }

            CatalogSection(title: "Color") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: Layout.swatchMinWidth), spacing: theme.metrics.spacing.sm)],
                    spacing: theme.metrics.spacing.sm
                ) {
                    ForEach(Self.colorSamples, id: \.name) { sample in
                        VStack(alignment: .leading, spacing: theme.metrics.spacing.xs) {
                            RoundedRectangle(cornerRadius: theme.metrics.radius.sm, style: .continuous)
                                .fill(theme.colors[keyPath: sample.keyPath])
                                .frame(height: Layout.swatchHeight)
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.metrics.radius.sm, style: .continuous)
                                        .strokeBorder(theme.colors.border, lineWidth: theme.metrics.border.regular)
                                }
                            Text(sample.name)
                                .appText(\.caption, color: \.textSecondary)
                        }
                    }
                }
            }

            CatalogSection(title: "Spacing") {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                    ForEach(Self.spacingSamples, id: \.name) { sample in
                        let value = theme.metrics.spacing[keyPath: sample.keyPath]
                        HStack(spacing: theme.metrics.spacing.md) {
                            Text(sample.name)
                                .appText(\.caption, color: \.textSecondary)
                                .frame(width: Layout.spacingLabelWidth, alignment: .leading)
                            RoundedRectangle(cornerRadius: theme.metrics.radius.xs, style: .continuous)
                                .fill(theme.colors.accentSubtle)
                                .frame(width: value, height: Layout.spacingBarHeight)
                            Text("\(Int(value))pt")
                                .appText(\.caption, color: \.textTertiary)
                        }
                    }
                }
            }

            CatalogSection(title: "Contrast (WCAG AA)") {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                    ForEach(ColorTokenContrastPairs.all, id: \.name) { pair in
                        let report = ColorContrast.report(
                            name: pair.name,
                            foreground: theme.colors[keyPath: pair.foreground],
                            background: theme.colors[keyPath: pair.background],
                            in: colorScheme,
                            threshold: pair.threshold
                        )

                        HStack(spacing: theme.metrics.spacing.sm) {
                            Image(verdictIcon(report.verdict))
                                .appIcon(\.xs, weight: .semibold)
                                .foregroundStyle(verdictColor(report.verdict))

                            Text(pair.name)
                                .appText(\.caption, color: \.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(report.formattedRatio)
                                .appText(\.caption, color: \.textTertiary)
                                .monospacedDigit()
                        }
                        // 통과 여부가 아이콘 색에만 있으므로 보고서 문장을 통째로 읽힌다.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(report.description)
                    }
                }
            }

            CatalogSection(title: "Icon") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: Layout.iconCellMinWidth), spacing: theme.metrics.spacing.sm)],
                    spacing: theme.metrics.spacing.md
                ) {
                    ForEach(AppIcon.allCases, id: \.self) { icon in
                        VStack(spacing: theme.metrics.spacing.xs) {
                            Image(icon)
                                .appIcon(\.lg)
                                .foregroundStyle(theme.colors.textPrimary)
                                // 바로 아래 이름이 라벨 역할을 한다.
                                .accessibilityHidden(true)
                            Text(String(describing: icon))
                                .appText(\.caption, color: \.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(Layout.iconNameMinScale)
                        }
                    }
                }
            }
        }
    }

    private static let fontSamples: [(name: String, keyPath: KeyPath<TypographyTokens, FontToken>)] = [
        ("display", \.display),
        ("titleLarge", \.titleLarge),
        ("titleMedium", \.titleMedium),
        ("titleSmall", \.titleSmall),
        ("bodyLarge", \.bodyLarge),
        ("bodyMedium", \.bodyMedium),
        ("bodySmall", \.bodySmall),
        ("label", \.label),
        ("caption", \.caption),
    ]

    private static let colorSamples: [(name: String, keyPath: KeyPath<ColorTokens, Color>)] = [
        ("accent", \.accent),
        ("accentSubtle", \.accentSubtle),
        ("surface", \.surface),
        ("surfaceMuted", \.surfaceMuted),
        ("background", \.background),
        ("textPrimary", \.textPrimary),
        ("textSecondary", \.textSecondary),
        ("border", \.border),
        ("success", \.success),
        ("warning", \.warning),
        ("danger", \.danger),
    ]

    private static let spacingSamples: [(name: String, keyPath: KeyPath<SpacingTokens, CGFloat>)] = [
        ("xxs", \.xxs), ("xs", \.xs), ("sm", \.sm), ("md", \.md),
        ("lg", \.lg), ("xl", \.xl), ("xxl", \.xxl), ("xxxl", \.xxxl),
    ]

    private func verdictIcon(_ verdict: ColorContrast.Report.Verdict) -> AppIcon {
        switch verdict {
        case .pass: .success
        case .fail: .error
        case .indeterminate: .warning
        }
    }

    /// 판정 불가(반투명 배경)는 미달과 구분되도록 보조 색으로 표시한다.
    private func verdictColor(_ verdict: ColorContrast.Report.Verdict) -> Color {
        switch verdict {
        case .pass: theme.colors.success
        case .fail: theme.colors.danger
        case .indeterminate: theme.colors.textSecondary
        }
    }
}

// MARK: - Previews

#Preview("Foundation / Dark") {
    FoundationCatalog()
        .theme(.standard)
        .preferredColorScheme(.dark)
}
