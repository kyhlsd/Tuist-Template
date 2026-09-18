//
//  TextStyleModifier.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 스케일링 적용 모디파이어

/// 토큰 하나를 실제 폰트/행간/자간으로 변환한다.
///
/// `ScaledMetric`은 초기화 시점에 기준값이 필요하므로,
/// 테마를 읽는 바깥 모디파이어와 스케일링을 담당하는 이 모디파이어를 분리했다.
private struct ScaledFontModifier: ViewModifier {
    private let token: FontToken
    private let provider: any FontProviding

    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledLineHeight: CGFloat

    init(token: FontToken, provider: any FontProviding) {
        self.token = token
        self.provider = provider
        _scaledSize = ScaledMetric(wrappedValue: token.size, relativeTo: token.textStyle)
        _scaledLineHeight = ScaledMetric(wrappedValue: token.lineHeight, relativeTo: token.textStyle)
    }

    func body(content: Content) -> some View {
        content
            .font(provider.font(size: scaledSize, weight: token.weight, design: token.design))
            .tracking(token.tracking)
            .lineSpacing(max(0, scaledLineHeight - scaledSize))
    }
}

// MARK: - 테마 연결 모디파이어

private struct AppTextStyleModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let fontKeyPath: KeyPath<TypographyTokens, FontToken>
    let colorKeyPath: KeyPath<ColorTokens, Color>?

    func body(content: Content) -> some View {
        let styled = content.modifier(
            ScaledFontModifier(
                token: theme.typography[keyPath: fontKeyPath],
                provider: theme.typography.provider
            )
        )

        if let colorKeyPath {
            styled.foregroundStyle(theme.colors[keyPath: colorKeyPath])
        } else {
            styled
        }
    }
}

// MARK: - 공개 API

public extension View {
    /// 타이포그래피 토큰과 색상 토큰을 한 번에 적용한다.
    ///
    /// ```swift
    /// Text("오늘의 알람")
    ///     .appText(\.titleMedium, color: \.textPrimary)
    /// ```
    /// - Parameters:
    ///   - font: `TypographyTokens`의 키패스.
    ///   - color: `ColorTokens`의 키패스. `nil`이면 상위에서 지정한 색을 유지한다.
    func appText(
        _ font: KeyPath<TypographyTokens, FontToken>,
        color: KeyPath<ColorTokens, Color>? = nil
    ) -> some View {
        modifier(AppTextStyleModifier(fontKeyPath: font, colorKeyPath: color))
    }

    /// 색상 토큰만 적용한다.
    func appForeground(_ color: KeyPath<ColorTokens, Color>) -> some View {
        modifier(ForegroundTokenModifier(keyPath: color))
    }
}

private struct ForegroundTokenModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let keyPath: KeyPath<ColorTokens, Color>

    func body(content: Content) -> some View {
        content.foregroundStyle(theme.colors[keyPath: keyPath])
    }
}
