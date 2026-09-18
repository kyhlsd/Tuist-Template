//
//  AppProgressViewStyle.swift
//  DesignSystem
//

import SwiftUI

/// 진행률을 막대로 표시하는 스타일.
///
/// `fractionCompleted`가 `nil`이면 불확정 상태이므로 좌우로 움직이는 인디케이터를 보여준다.
public struct AppLinearProgressViewStyle: ProgressViewStyle {
    public init(
        tint: KeyPath<ColorTokens, Color> = \.accent,
        showsPercentage: Bool = false
    ) {
        self.tint = tint
        self.showsPercentage = showsPercentage
    }

    public var tint: KeyPath<ColorTokens, Color> = \.accent
    public var showsPercentage: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        AppLinearProgressContent(
            configuration: configuration,
            tint: tint,
            showsPercentage: showsPercentage
        )
    }
}

private struct AppLinearProgressContent: View {
    private enum Layout {
        static let barHeight: CGFloat = 6
        /// 불확정 상태에서 움직이는 인디케이터가 트랙에서 차지하는 비율.
        static let indeterminateWidthRatio: CGFloat = 0.3
        /// 불확정 인디케이터가 트랙을 한 번 지나가는 시간.
        static let indeterminateDuration: Double = 1.2
    }

    let configuration: ProgressViewStyleConfiguration
    let tint: KeyPath<ColorTokens, Color>
    let showsPercentage: Bool

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 불확정 인디케이터의 진행도. 0이면 트랙 왼쪽 바깥, 1이면 오른쪽 바깥.
    @State private var indeterminateProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
            header
            bar
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var header: some View {
        if configuration.label != nil || showsPercentage {
            HStack {
                if let label = configuration.label {
                    label.appText(\.bodySmall, color: \.textSecondary)
                }

                Spacer(minLength: theme.metrics.spacing.sm)

                if showsPercentage, let fraction = configuration.fractionCompleted {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .appText(\.caption, color: \.textTertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var bar: some View {
        // 트랙 모양. 인디케이터를 이 도형으로 잘라 내야 막대가 밖으로 새지 않는다.
        let trackShape = Capsule(style: .continuous)

        return GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let fillWidth = fillWidth(in: totalWidth)

            ZStack(alignment: .leading) {
                trackShape.fill(theme.colors.surfaceMuted)

                trackShape
                    .fill(theme.colors[keyPath: tint])
                    .frame(width: fillWidth)
                    .offset(x: offset(totalWidth: totalWidth, fillWidth: fillWidth))
            }
            // `offset`은 레이아웃 프레임을 바꾸지 않고 그리기 위치만 옮기므로
            // 클리핑이 없으면 부모 경계를 넘어 그려진다.
            .clipShape(trackShape)
        }
        .frame(height: Layout.barHeight)
        .onAppear(perform: startIndeterminateAnimationIfNeeded)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard let fraction = configuration.fractionCompleted else {
            return totalWidth * Layout.indeterminateWidthRatio
        }
        return totalWidth * CGFloat(min(max(fraction, 0), 1))
    }

    /// 불확정 상태에서 인디케이터가 왼쪽 바깥 → 오른쪽 바깥으로 지나가도록 위치를 계산한다.
    private func offset(totalWidth: CGFloat, fillWidth: CGFloat) -> CGFloat {
        guard configuration.fractionCompleted == nil else { return 0 }
        guard !reduceMotion else {
            // 모션 감소 설정에서는 가운데 고정.
            return (totalWidth - fillWidth) / 2
        }
        return -fillWidth + (totalWidth + fillWidth) * indeterminateProgress
    }

    private func startIndeterminateAnimationIfNeeded() {
        guard configuration.fractionCompleted == nil, !reduceMotion else { return }
        withAnimation(.linear(duration: Layout.indeterminateDuration).repeatForever(autoreverses: false)) {
            indeterminateProgress = 1
        }
    }

    private var accessibilityValue: String {
        guard let fraction = configuration.fractionCompleted else { return DesignSystemStrings.inProgress }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

public extension ProgressViewStyle where Self == AppLinearProgressViewStyle {
    static var appLinear: AppLinearProgressViewStyle {
        AppLinearProgressViewStyle()
    }

    static func appLinear(
        tint: KeyPath<ColorTokens, Color> = \.accent,
        showsPercentage: Bool = false
    ) -> AppLinearProgressViewStyle {
        AppLinearProgressViewStyle(tint: tint, showsPercentage: showsPercentage)
    }
}
