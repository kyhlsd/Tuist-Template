//
//  AppListRow.swift
//  DesignSystem
//

import SwiftUI

// MARK: - Section Header

/// 목록 구획을 나누는 헤더.
public struct AppSectionHeader<Accessory: View>: View {
    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    public let title: String
    public var subtitle: String?
    @ViewBuilder public let accessory: Accessory

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.metrics.spacing.sm) {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.xxs) {
                Text(title)
                    .appText(\.titleSmall, color: \.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .appText(\.bodySmall, color: \.textSecondary)
                }
            }

            Spacer(minLength: theme.metrics.spacing.sm)

            accessory
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

public extension AppSectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - List Row

/// 아이콘 + 제목/부제 + 액세서리로 구성된 목록 행.
public struct AppListRow<Accessory: View>: View {
    public init(
        icon: AppIcon? = nil,
        iconTint: KeyPath<ColorTokens, Color> = \.accent,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    public var icon: AppIcon?
    public var iconTint: KeyPath<ColorTokens, Color> = \.accent
    public let title: String
    public var subtitle: String?
    @ViewBuilder public let accessory: Accessory

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.md) {
            if let icon {
                Image(icon)
                    .appIcon(\.md)
                    .foregroundStyle(theme.colors[keyPath: iconTint])
                    // 행의 의미는 제목이 전달한다. 아이콘까지 읽으면 탐색만 길어진다.
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: theme.metrics.spacing.xxs) {
                Text(title)
                    .appText(\.bodyLarge, color: \.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .appText(\.bodySmall, color: \.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory
        }
        .padding(.vertical, theme.metrics.spacing.sm)
        .frame(minHeight: theme.metrics.minimumHitTarget)
        .contentShape(Rectangle())
    }
}

public extension AppListRow where Accessory == AppChevron {
    /// 화면 이동을 암시하는 기본 형태.
    init(
        icon: AppIcon? = nil,
        iconTint: KeyPath<ColorTokens, Color> = \.accent,
        title: String,
        subtitle: String? = nil
    ) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle) {
            AppChevron()
        }
    }
}

/// 목록 행 오른쪽의 이동 표시.
public struct AppChevron: View {
    public init() {}

    @Environment(\.theme) private var theme

    public var body: some View {
        Image(.forward)
            .appIcon(\.xs, weight: .semibold)
            .foregroundStyle(theme.colors.textTertiary)
            .accessibilityHidden(true)
    }
}

/// 목록 행 오른쪽의 보조 텍스트.
public struct AppRowDetail: View {
    public init(
        text: String
    ) {
        self.text = text
    }

    public let text: String

    public var body: some View {
        Text(text)
            .appText(\.bodyMedium, color: \.textSecondary)
            .lineLimit(1)
    }
}

// MARK: - Divider

/// 토큰 기반 구분선.
public struct AppDivider: View {
    public init(
        inset: KeyPath<SpacingTokens, CGFloat>? = nil
    ) {
        self.inset = inset
    }

    public var inset: KeyPath<SpacingTokens, CGFloat>?

    @Environment(\.theme) private var theme

    public var body: some View {
        Rectangle()
            .fill(theme.colors.separator)
            .frame(height: theme.metrics.border.regular)
            .padding(.leading, inset.map { theme.metrics.spacing[keyPath: $0] } ?? 0)
            .accessibilityHidden(true)
    }
}
