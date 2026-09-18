//
//  AppLabelStyle.swift
//  DesignSystem
//

import SwiftUI

// MARK: - Label

/// 아이콘과 제목의 간격·정렬을 토큰으로 통일한 기본 라벨.
public struct AppLabelStyle: LabelStyle {
    public init(
        spacing: KeyPath<SpacingTokens, CGFloat> = \.sm,
        iconSize: KeyPath<IconSizeTokens, CGFloat> = \.sm,
        iconColor: KeyPath<ColorTokens, Color>? = nil
    ) {
        self.spacing = spacing
        self.iconSize = iconSize
        self.iconColor = iconColor
    }

    public var spacing: KeyPath<SpacingTokens, CGFloat> = \.sm
    public var iconSize: KeyPath<IconSizeTokens, CGFloat> = \.sm
    public var iconColor: KeyPath<ColorTokens, Color>?

    public func makeBody(configuration: Configuration) -> some View {
        AppLabelContent(
            configuration: configuration,
            spacing: spacing,
            iconSize: iconSize,
            iconColor: iconColor
        )
    }
}

private struct AppLabelContent: View {
    let configuration: LabelStyleConfiguration
    let spacing: KeyPath<SpacingTokens, CGFloat>
    let iconSize: KeyPath<IconSizeTokens, CGFloat>
    let iconColor: KeyPath<ColorTokens, Color>?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.metrics.spacing[keyPath: spacing]) {
            icon
            configuration.title
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let iconColor {
            configuration.icon
                .appIcon(iconSize)
                .foregroundStyle(theme.colors[keyPath: iconColor])
        } else {
            configuration.icon
                .appIcon(iconSize)
        }
    }
}

/// 설정 화면 등에서 쓰는, 아이콘을 둥근 사각형 배경 위에 올리는 라벨.
public struct AppTintedLabelStyle: LabelStyle {
    public init(
        tint: KeyPath<ColorTokens, Color> = \.accent,
        background: KeyPath<ColorTokens, Color> = \.accentSubtle
    ) {
        self.tint = tint
        self.background = background
    }

    public var tint: KeyPath<ColorTokens, Color> = \.accent
    public var background: KeyPath<ColorTokens, Color> = \.accentSubtle

    public func makeBody(configuration: Configuration) -> some View {
        AppTintedLabelContent(configuration: configuration, tint: tint, background: background)
    }
}

private struct AppTintedLabelContent: View {
    private enum Layout {
        static let containerSize: CGFloat = 30
    }

    let configuration: LabelStyleConfiguration
    let tint: KeyPath<ColorTokens, Color>
    let background: KeyPath<ColorTokens, Color>

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.metrics.spacing.md) {
            configuration.icon
                .appIcon(\.sm, weight: .semibold)
                .foregroundStyle(theme.colors[keyPath: tint])
                .frame(width: Layout.containerSize, height: Layout.containerSize)
                .background(
                    theme.colors[keyPath: background],
                    in: RoundedRectangle(cornerRadius: theme.metrics.radius.sm, style: .continuous)
                )

            configuration.title
        }
    }
}

public extension LabelStyle where Self == AppLabelStyle {
    static var app: AppLabelStyle {
        AppLabelStyle()
    }

    static func app(
        spacing: KeyPath<SpacingTokens, CGFloat> = \.sm,
        iconSize: KeyPath<IconSizeTokens, CGFloat> = \.sm,
        iconColor: KeyPath<ColorTokens, Color>? = nil
    ) -> AppLabelStyle {
        AppLabelStyle(spacing: spacing, iconSize: iconSize, iconColor: iconColor)
    }
}

public extension LabelStyle where Self == AppTintedLabelStyle {
    static var appTinted: AppTintedLabelStyle {
        AppTintedLabelStyle()
    }

    static func appTinted(
        tint: KeyPath<ColorTokens, Color>,
        background: KeyPath<ColorTokens, Color>
    ) -> AppTintedLabelStyle {
        AppTintedLabelStyle(tint: tint, background: background)
    }
}
