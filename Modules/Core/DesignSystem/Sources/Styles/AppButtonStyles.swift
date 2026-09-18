//
//  AppButtonStyles.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 공통 레이아웃

/// 버튼 크기 프리셋.
public enum AppButtonSize {
    case small
    case medium
    case large

    /// 버튼의 최소 높이. 글자가 커지면 버튼이 이보다 커진다.
    ///
    /// 고정 높이로 두면 접근성 글자 크기에서 라벨이 잘린다.
    public func height(_ metrics: MetricTokens) -> CGFloat {
        switch self {
        case .small: max(metrics.minimumHitTarget - Layout.compactReduction, Layout.compactFloor)
        case .medium: metrics.minimumHitTarget
        case .large: Layout.largeHeight
        }
    }

    private enum Layout {
        /// small 은 목록·툴바 안에서 쓰므로 기본 터치 영역보다 조금 낮춘다.
        static let compactReduction: CGFloat = 8
        /// 그래도 이 아래로는 내리지 않는다.
        static let compactFloor: CGFloat = 36
        /// 화면 하단 주요 CTA.
        static let largeHeight: CGFloat = 54
    }

    public var fontKeyPath: KeyPath<TypographyTokens, FontToken> {
        switch self {
        case .small: \.bodySmall
        case .medium, .large: \.label
        }
    }

    public func horizontalPadding(_ metrics: MetricTokens) -> CGFloat {
        switch self {
        case .small: metrics.spacing.md
        case .medium: metrics.spacing.lg
        case .large: metrics.spacing.xl
        }
    }
}

// MARK: - Primary

/// 화면당 하나만 사용하는 주요 액션 버튼.
///
/// `ButtonStyle`은 `DynamicProperty`를 추적하지 않으므로
/// `@Environment` 사용을 위해 내부 `View`로 한 단계 감싼다.
///
/// - Important: 중첩 타입 이름을 `Body`로 지으면 `ButtonStyle.Body`
///   associatedtype의 witness로 추론되어 접근 수준 에러가 발생한다.
///   반드시 다른 이름을 사용한다.
public struct PrimaryButtonStyle: ButtonStyle {
    public init(
        size: AppButtonSize = .medium,
        isFullWidth: Bool = true
    ) {
        self.size = size
        self.isFullWidth = isFullWidth
    }

    public var size: AppButtonSize = .medium
    public var isFullWidth: Bool = true

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonContent(configuration: configuration, size: size, isFullWidth: isFullWidth)
    }
}

private struct PrimaryButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let size: AppButtonSize
    let isFullWidth: Bool

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.radius.md, style: .continuous)

        configuration.label
            .appText(size.fontKeyPath)
            .foregroundStyle(theme.colors.onAccent)
            .padding(.horizontal, size.horizontalPadding(metrics))
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            // 글자가 커져 두 줄이 되어도 위아래가 붙지 않도록 최소 여백을 둔다.
            .padding(.vertical, metrics.spacing.xs)
            .frame(minHeight: size.height(metrics))
            .background(backgroundColor(isPressed: configuration.isPressed), in: shape)
            .contentShape(shape)
            .animation(.app(metrics.duration.fast), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return theme.colors.accentDisabled }
        return isPressed ? theme.colors.accentPressed : theme.colors.accent
    }
}

// MARK: - Secondary

/// 테두리만 있는 보조 액션 버튼.
public struct SecondaryButtonStyle: ButtonStyle {
    public init(
        size: AppButtonSize = .medium,
        isFullWidth: Bool = true
    ) {
        self.size = size
        self.isFullWidth = isFullWidth
    }

    public var size: AppButtonSize = .medium
    public var isFullWidth: Bool = true

    public func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonContent(configuration: configuration, size: size, isFullWidth: isFullWidth)
    }
}

private struct SecondaryButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let size: AppButtonSize
    let isFullWidth: Bool

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let metrics = theme.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.radius.md, style: .continuous)

        configuration.label
            .appText(size.fontKeyPath)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding(metrics))
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            // 글자가 커져 두 줄이 되어도 위아래가 붙지 않도록 최소 여백을 둔다.
            .padding(.vertical, metrics.spacing.xs)
            .frame(minHeight: size.height(metrics))
            .background(
                configuration.isPressed ? theme.colors.surfacePressed : theme.colors.surface,
                in: shape
            )
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: metrics.border.regular)
            }
            .contentShape(shape)
            .animation(.app(metrics.duration.fast), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        isEnabled ? theme.colors.textPrimary : theme.colors.textDisabled
    }

    private var borderColor: Color {
        isEnabled ? theme.colors.border : theme.colors.separator
    }
}

// MARK: - Text(Plain)

/// 배경 없이 텍스트만 노출하는 3차 액션 버튼.
public struct TextButtonStyle: ButtonStyle {
    public init(
        role: Role = .normal
    ) {
        self.role = role
    }

    public enum Role {
        case normal
        case destructive
    }

    public var role: Role = .normal

    public func makeBody(configuration: Configuration) -> some View {
        TextButtonContent(configuration: configuration, role: role)
    }
}

private struct TextButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let role: TextButtonStyle.Role

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .appText(\.label)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, theme.metrics.spacing.sm)
            .frame(minHeight: theme.metrics.minimumHitTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? StateOpacity.pressedText : 1)
            .animation(.app(theme.metrics.duration.instant), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return theme.colors.textDisabled }
        switch role {
        case .normal: return theme.colors.accent
        case .destructive: return theme.colors.danger
        }
    }
}

// MARK: - 편의 접근자

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var appPrimary: PrimaryButtonStyle {
        PrimaryButtonStyle()
    }

    static func appPrimary(size: AppButtonSize, isFullWidth: Bool = true) -> PrimaryButtonStyle {
        PrimaryButtonStyle(size: size, isFullWidth: isFullWidth)
    }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var appSecondary: SecondaryButtonStyle {
        SecondaryButtonStyle()
    }

    static func appSecondary(size: AppButtonSize, isFullWidth: Bool = true) -> SecondaryButtonStyle {
        SecondaryButtonStyle(size: size, isFullWidth: isFullWidth)
    }
}

public extension ButtonStyle where Self == TextButtonStyle {
    static var appTextButton: TextButtonStyle {
        TextButtonStyle()
    }

    static func appTextButton(role: TextButtonStyle.Role) -> TextButtonStyle {
        TextButtonStyle(role: role)
    }
}
