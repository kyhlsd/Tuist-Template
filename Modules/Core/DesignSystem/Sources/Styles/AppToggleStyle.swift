//
//  AppToggleStyle.swift
//  DesignSystem
//

import SwiftUI

// MARK: - Switch

/// 시스템 스위치와 같은 형태이되 브랜드 컬러와 토큰을 따르는 토글.
public struct AppSwitchToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        AppSwitchContent(configuration: configuration)
    }
}

private struct AppSwitchContent: View {
    /// 컴포넌트 고유 치수.
    ///
    /// 스위치 트랙 크기는 HIG가 정한 고정값이라 테마에 따라 변하지 않는다.
    /// 시맨틱 토큰에 넣으면 컴포넌트 이름이 토큰으로 새어 들어가므로
    /// 컴포넌트 내부 상수로 둔다.
    private enum Layout {
        static let trackWidth: CGFloat = 51
        static let trackHeight: CGFloat = 31
        static let knobInset: CGFloat = 2
        /// 손잡이가 넘어가는 스프링 응답 시간. 시스템 스위치와 비슷한 빠르기.
        static let toggleResponse: Double = 0.25
        static var knobDiameter: CGFloat {
            trackHeight - knobInset * 2
        }

        static var knobOffset: CGFloat {
            (trackWidth - knobDiameter) / 2 - knobInset
        }
    }

    let configuration: ToggleStyleConfiguration

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: theme.metrics.spacing.md) {
            configuration.label
                .appText(\.bodyLarge, color: isEnabled ? \.textPrimary : \.textDisabled)

            Spacer(minLength: theme.metrics.spacing.sm)

            track
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.appSpring(response: Layout.toggleResponse)) {
                configuration.isOn.toggle()
            }
        }
        // 접근성 트레잇(.isToggle)과 값 읽기는 상위 `Toggle`이 제공하므로
        // 여기서 별도로 선언하면 중복 안내가 발생한다.
    }

    private var track: some View {
        Capsule(style: .circular)
            .fill(trackColor)
            .frame(width: Layout.trackWidth, height: Layout.trackHeight)
            .overlay {
                Circle()
                    .fill(theme.colors.controlKnob)
                    .frame(width: Layout.knobDiameter, height: Layout.knobDiameter)
                    .appShadow(\.card)
                    .offset(x: configuration.isOn ? Layout.knobOffset : -Layout.knobOffset)
            }
            .opacity(isEnabled ? 1 : StateOpacity.disabled)
    }

    private var trackColor: Color {
        guard isEnabled else { return theme.colors.surfaceMuted }
        return configuration.isOn ? theme.colors.accent : theme.colors.borderStrong
    }
}

// MARK: - Checkbox

/// 목록 다중 선택 등에 사용하는 체크박스 형태 토글.
public struct AppCheckboxToggleStyle: ToggleStyle {
    public init(
        alignment: HorizontalAlignment = .leading
    ) {
        self.alignment = alignment
    }

    /// 체크박스를 라벨의 왼쪽에 둘지 오른쪽에 둘지.
    public var alignment: HorizontalAlignment = .leading

    public func makeBody(configuration: Configuration) -> some View {
        AppCheckboxContent(configuration: configuration, alignment: alignment)
    }
}

private struct AppCheckboxContent: View {
    private enum Layout {
        static let boxSize: CGFloat = 22
        /// 상자 안 체크 표시가 차지하는 비율.
        static let checkmarkRatio: CGFloat = 0.55
    }

    let configuration: ToggleStyleConfiguration
    let alignment: HorizontalAlignment

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: theme.metrics.spacing.md) {
            if alignment == .leading {
                box
            }

            configuration.label
                .appText(\.bodyLarge, color: isEnabled ? \.textPrimary : \.textDisabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if alignment == .trailing {
                box
            }
        }
        .frame(minHeight: theme.metrics.minimumHitTarget)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.app(theme.metrics.duration.fast)) {
                configuration.isOn.toggle()
            }
        }
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: theme.metrics.radius.xs, style: .continuous)
            .fill(configuration.isOn ? theme.colors.accent : Color.clear)
            .frame(width: Layout.boxSize, height: Layout.boxSize)
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.radius.xs, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: theme.metrics.border.thick)
            }
            .overlay {
                if configuration.isOn {
                    Image(.checkmark)
                        .font(.system(size: Layout.boxSize * Layout.checkmarkRatio, weight: .bold))
                        // 켜짐 여부는 Toggle 이 값으로 읽어 주므로 표시 자체는 장식이다.
                        .accessibilityHidden(true)
                        .foregroundStyle(theme.colors.onAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .opacity(isEnabled ? 1 : StateOpacity.disabled)
    }

    private var borderColor: Color {
        guard isEnabled else { return theme.colors.border }
        return configuration.isOn ? theme.colors.accent : theme.colors.borderStrong
    }
}

// MARK: - 편의 접근자

public extension ToggleStyle where Self == AppSwitchToggleStyle {
    static var appSwitch: AppSwitchToggleStyle {
        AppSwitchToggleStyle()
    }
}

public extension ToggleStyle where Self == AppCheckboxToggleStyle {
    static var appCheckbox: AppCheckboxToggleStyle {
        AppCheckboxToggleStyle()
    }

    static func appCheckbox(alignment: HorizontalAlignment) -> AppCheckboxToggleStyle {
        AppCheckboxToggleStyle(alignment: alignment)
    }
}
