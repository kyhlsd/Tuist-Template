//
//  InteractionModifiers.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 포커스 링

/// 키보드·외부 컨트롤 조작 시 현재 포커스 위치를 시각적으로 알린다.
///
/// iPad 하드웨어 키보드, Mac Catalyst, 스위치 제어 사용자에게는 포커스 표시가
/// 유일한 위치 단서이므로 색 변화만으로는 부족하다.
private struct FocusRingModifier: ViewModifier {
    let isFocused: Bool
    let radiusKeyPath: KeyPath<RadiusTokens, CGFloat>

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let radius = theme.metrics.radius[keyPath: radiusKeyPath]
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .overlay {
                shape
                    .strokeBorder(
                        theme.colors.accent.opacity(isFocused ? 1 : 0),
                        lineWidth: theme.metrics.border.thick
                    )
            }
            .overlay {
                // 바깥으로 번지는 얇은 후광. 배경색과 무관하게 링이 보이게 한다.
                shape
                    .inset(by: -theme.metrics.border.focus)
                    .strokeBorder(
                        theme.colors.accent.opacity(isFocused ? StateOpacity.subtleTint : 0),
                        lineWidth: theme.metrics.border.focus
                    )
            }
            .animation(.app(theme.metrics.duration.fast), value: isFocused)
    }
}

// MARK: - 최소 터치 영역

/// 시각적 크기와 무관하게 최소 터치 영역을 확보한다.
///
/// 아이콘 버튼처럼 그림이 작은 컨트롤은 44pt 미만이 되기 쉬운데,
/// HIG 권장치를 밑돌면 손이 큰 사용자나 이동 중 조작에서 실패율이 크게 올라간다.
private struct MinimumHitTargetModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let target = theme.metrics.minimumHitTarget

        content
            .frame(minWidth: target, minHeight: target)
            // 투명 영역도 터치를 받도록 한다.
            .contentShape(Rectangle())
    }
}

// MARK: - 조건부 비활성 표현

/// 비활성 상태를 흐림으로 표현한다.
///
/// `disabled(_:)`만 쓰면 조작이 막혔다는 사실이 시각적으로 드러나지 않는 경우가 있다.
private struct DisabledAppearanceModifier: ViewModifier {
    let isDisabled: Bool

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .opacity(isDisabled ? StateOpacity.disabled : 1)
            .disabled(isDisabled)
            .animation(.app(theme.metrics.duration.fast), value: isDisabled)
    }
}

// MARK: - 공개 API

public extension View {
    /// 포커스 링을 표시한다.
    ///
    /// ```swift
    /// @FocusState private var isFocused: Bool
    ///
    /// TextField("이름", text: $name)
    ///     .focused($isFocused)
    ///     .appFocusRing(isFocused)
    /// ```
    func appFocusRing(
        _ isFocused: Bool,
        radius: KeyPath<RadiusTokens, CGFloat> = \.md
    ) -> some View {
        modifier(FocusRingModifier(isFocused: isFocused, radiusKeyPath: radius))
    }

    /// 최소 터치 영역(44pt)을 확보한다.
    func appMinimumHitTarget() -> some View {
        modifier(MinimumHitTargetModifier())
    }

    /// 비활성 상태를 흐림으로 함께 표현한다.
    func appDisabled(_ isDisabled: Bool) -> some View {
        modifier(DisabledAppearanceModifier(isDisabled: isDisabled))
    }
}

// MARK: - 아이콘 버튼

/// 아이콘 하나만 있는 버튼. 터치 영역과 접근성 라벨을 강제한다.
///
/// `Image`에 `onTapGesture`를 붙이는 방식은 터치 영역이 좁고 VoiceOver가
/// 버튼으로 인식하지 못하는 문제가 반복되므로, 전용 컴포넌트로 고정한다.
public struct AppIconButton: View {
    public init(
        icon: AppIcon,
        accessibilityLabel: String,
        size: KeyPath<IconSizeTokens, CGFloat> = \.md,
        tint: KeyPath<ColorTokens, Color> = \.textPrimary,
        background: KeyPath<ColorTokens, Color>? = nil,
        haptic: AppHaptic? = .light,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.size = size
        self.tint = tint
        self.background = background
        self.haptic = haptic
        self.action = action
    }

    public let icon: AppIcon
    /// VoiceOver가 읽을 설명. 아이콘만으로는 의미를 전달할 수 없으므로 필수다.
    public let accessibilityLabel: String
    public var size: KeyPath<IconSizeTokens, CGFloat> = \.md
    public var tint: KeyPath<ColorTokens, Color> = \.textPrimary
    /// 터치 영역 크기의 원형 배경. 시트 닫기 버튼처럼 버튼임을 드러내야 할 때 쓴다. `nil`이면 배경 없음.
    public var background: KeyPath<ColorTokens, Color>?
    public var haptic: AppHaptic? = .light
    public let action: () -> Void

    @Environment(\.theme) private var theme

    public var body: some View {
        Button {
            haptic?.trigger()
            action()
        } label: {
            Image(icon)
                .appIcon(size, weight: .semibold)
                .foregroundStyle(theme.colors[keyPath: tint])
                .appMinimumHitTarget()
                .background {
                    if let background {
                        Circle().fill(theme.colors[keyPath: background])
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
