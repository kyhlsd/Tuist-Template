//
//  AppPressableStyle.swift
//  DesignSystem
//

import SwiftUI

/// 카드나 목록 행처럼 넓은 영역을 눌렀을 때의 공통 반응.
///
/// 각 화면에서 `scaleEffect`와 `opacity`를 즉흥적으로 넣으면 누름 강도가 제각각이 되므로
/// 하나의 스타일로 통일한다.
public struct AppPressableStyle: ButtonStyle {
    public init(
        pressedScale: CGFloat = 0.98,
        appliesHighlight: Bool = true,
        highlightRadius: KeyPath<RadiusTokens, CGFloat> = \.lg,
        haptic: AppHaptic? = .selection
    ) {
        self.pressedScale = pressedScale
        self.appliesHighlight = appliesHighlight
        self.highlightRadius = highlightRadius
        self.haptic = haptic
    }

    /// 눌렀을 때 축소 비율. 넓은 영역일수록 작게 줄여야 자연스럽다.
    public var pressedScale: CGFloat = 0.98
    /// 눌린 동안 표면색을 바꿀지 여부.
    public var appliesHighlight: Bool = true
    /// 하이라이트에 사용할 모서리 반경. 대상 카드와 맞춰야 한다.
    public var highlightRadius: KeyPath<RadiusTokens, CGFloat> = \.lg
    public var haptic: AppHaptic? = .selection

    public func makeBody(configuration: Configuration) -> some View {
        PressableContent(
            configuration: configuration,
            pressedScale: pressedScale,
            appliesHighlight: appliesHighlight,
            highlightRadius: highlightRadius,
            haptic: haptic
        )
    }
}

private struct PressableContent: View {
    let configuration: ButtonStyleConfiguration
    let pressedScale: CGFloat
    let appliesHighlight: Bool
    let highlightRadius: KeyPath<RadiusTokens, CGFloat>
    let haptic: AppHaptic?

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .background {
                if appliesHighlight, configuration.isPressed {
                    RoundedRectangle(
                        cornerRadius: theme.metrics.radius[keyPath: highlightRadius],
                        style: .continuous
                    )
                    .fill(theme.colors.surfacePressed)
                }
            }
            // 모션 감소 설정에서는 크기 변화 대신 투명도로만 반응한다.
            .scaleEffect(scaleValue)
            .opacity(opacityValue)
            .animation(.app(theme.metrics.duration.fast), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, isEnabled, let haptic else { return }
                haptic.trigger()
            }
    }

    private var scaleValue: CGFloat {
        guard !reduceMotion, configuration.isPressed else { return 1 }
        return pressedScale
    }

    private var opacityValue: Double {
        guard isEnabled else { return StateOpacity.disabled }
        guard reduceMotion, configuration.isPressed else { return 1 }
        return StateOpacity.pressed
    }
}

// MARK: - 편의 접근자

public extension ButtonStyle where Self == AppPressableStyle {
    static var appPressable: AppPressableStyle {
        AppPressableStyle()
    }

    static func appPressable(
        scale: CGFloat = 0.98,
        highlightRadius: KeyPath<RadiusTokens, CGFloat> = \.lg,
        haptic: AppHaptic? = .selection
    ) -> AppPressableStyle {
        AppPressableStyle(
            pressedScale: scale,
            highlightRadius: highlightRadius,
            haptic: haptic
        )
    }
}

// MARK: - 뷰 확장

public extension View {
    /// 임의의 뷰를 눌러서 실행되는 영역으로 만든다.
    ///
    /// `Button`으로 감싸므로 VoiceOver가 버튼으로 인식하고 키보드 조작도 가능하다.
    /// `onTapGesture`와 달리 접근성 트레잇을 따로 선언할 필요가 없다.
    ///
    /// ```swift
    /// VStack { ... }
    ///     .appCard()
    ///     .appPressable { openDetail() }
    /// ```
    func appPressable(
        scale: CGFloat = 0.98,
        highlightRadius: KeyPath<RadiusTokens, CGFloat> = \.lg,
        haptic: AppHaptic? = .selection,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { self }
            .buttonStyle(
                .appPressable(scale: scale, highlightRadius: highlightRadius, haptic: haptic)
            )
    }
}
