//
//  AppBadge.swift
//  DesignSystem
//

import SwiftUI

// MARK: - Badge

/// 상태나 분류를 나타내는 읽기 전용 라벨.
public struct AppBadge: View {
    public init(
        text: String,
        style: Style = .neutral,
        icon: AppIcon? = nil
    ) {
        self.text = text
        self.style = style
        self.icon = icon
    }

    /// 배지 의미 구분. 색 조합을 역할 단위로 묶어 호출부가 색을 직접 고르지 않게 한다.
    public enum Style {
        case neutral
        case accent
        case success
        case warning
        case danger

        var foreground: KeyPath<ColorTokens, Color> {
            switch self {
            case .neutral: \.textSecondary
            case .accent: \.accent
            case .success: \.success
            case .warning: \.warning
            case .danger: \.danger
            }
        }

        var background: KeyPath<ColorTokens, Color> {
            switch self {
            case .neutral: \.surfaceMuted
            case .accent: \.accentSubtle
            case .success: \.successSubtle
            case .warning: \.warningSubtle
            case .danger: \.dangerSubtle
            }
        }
    }

    public let text: String
    public var style: Style = .neutral
    public var icon: AppIcon?

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.xs) {
            if let icon {
                Image(icon).appIcon(\.xs, weight: .semibold).accessibilityHidden(true)
            }
            Text(text)
                .appText(\.caption)
        }
        .foregroundStyle(theme.colors[keyPath: style.foreground])
        .padding(.horizontal, theme.metrics.spacing.sm)
        .padding(.vertical, theme.metrics.spacing.xs)
        .background(
            theme.colors[keyPath: style.background],
            in: Capsule(style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chip

/// 선택 가능한 필터 칩.
public struct AppChip: View {
    public init(
        text: String,
        icon: AppIcon? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public let text: String
    public var icon: AppIcon?
    public var isSelected: Bool
    public let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public var body: some View {
        Button(action: action) {
            HStack(spacing: theme.metrics.spacing.xs) {
                if let icon {
                    Image(icon).appIcon(\.xs, weight: .semibold).accessibilityHidden(true)
                }
                Text(text)
                    .appText(\.bodySmall)
            }
        }
        .buttonStyle(ChipButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChipContent(configuration: configuration, isSelected: isSelected)
    }
}

private struct ChipContent: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, theme.metrics.spacing.md)
            // small 버튼과 같은 높이 규칙을 쓴다.
            .frame(minHeight: AppButtonSize.small.height(theme.metrics))
            .background(backgroundColor, in: Capsule(style: .continuous))
            .overlay {
                if !isSelected {
                    Capsule(style: .continuous)
                        .strokeBorder(theme.colors.border, lineWidth: theme.metrics.border.regular)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? StateOpacity.pressed : 1)
            .animation(.app(theme.metrics.duration.fast), value: isSelected)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return theme.colors.textDisabled }
        return isSelected ? theme.colors.onAccent : theme.colors.textSecondary
    }

    private var backgroundColor: Color {
        guard isEnabled else { return theme.colors.surfaceMuted }
        return isSelected ? theme.colors.accent : theme.colors.surface
    }
}
