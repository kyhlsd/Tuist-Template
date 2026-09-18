//
//  SurfaceModifiers.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 그림자

private struct ShadowTokenModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let keyPath: KeyPath<ShadowTokens, ShadowToken>

    func body(content: Content) -> some View {
        let token = theme.metrics.shadow[keyPath: keyPath]
        return content.shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

// MARK: - 카드

private struct CardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let paddingKeyPath: KeyPath<SpacingTokens, CGFloat>
    let radiusKeyPath: KeyPath<RadiusTokens, CGFloat>
    let showsBorder: Bool
    let shadowKeyPath: KeyPath<ShadowTokens, ShadowToken>?

    func body(content: Content) -> some View {
        let radius = theme.metrics.radius[keyPath: radiusKeyPath]
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        let base = content
            .padding(theme.metrics.spacing[keyPath: paddingKeyPath])
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface, in: shape)
            .overlay {
                if showsBorder {
                    shape.strokeBorder(
                        theme.colors.border,
                        lineWidth: theme.metrics.border.regular
                    )
                }
            }

        if let shadowKeyPath {
            base.modifier(ShadowTokenModifier(keyPath: shadowKeyPath))
        } else {
            base
        }
    }
}

// MARK: - 화면 여백

private struct ScreenPaddingModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.padding(edges, resolvedPadding)
    }

    /// iPad와 iPhone 가로 모드에서는 여백을 넓힌다.
    private var resolvedPadding: CGFloat {
        horizontalSizeClass == .regular
            ? theme.metrics.spacing.screenHorizontalRegular
            : theme.metrics.spacing.screenHorizontal
    }
}

// MARK: - 읽기 좋은 폭

/// 넓은 화면에서 콘텐츠가 지나치게 늘어나지 않도록 상한을 두고 가운데 정렬한다.
private struct ReadableWidthModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let maxWidth: KeyPath<MetricTokens, CGFloat>

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: theme.metrics[keyPath: maxWidth])
            // 바깥 프레임을 한 번 더 씌워 남는 공간을 양쪽으로 균등 분배한다.
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 화면 배경

private struct ScreenBackgroundModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.background(theme.colors.background.ignoresSafeArea())
    }
}

// MARK: - 공개 API

public extension View {
    /// 카드 형태의 서피스를 적용한다.
    func appCard(
        padding: KeyPath<SpacingTokens, CGFloat> = \.lg,
        radius: KeyPath<RadiusTokens, CGFloat> = \.lg,
        showsBorder: Bool = true,
        shadow: KeyPath<ShadowTokens, ShadowToken>? = \.card
    ) -> some View {
        modifier(
            CardModifier(
                paddingKeyPath: padding,
                radiusKeyPath: radius,
                showsBorder: showsBorder,
                shadowKeyPath: shadow
            )
        )
    }

    /// 화면 표준 좌우 여백을 적용한다. 레귤러 폭에서는 자동으로 넓어진다.
    func appScreenPadding(_ edges: Edge.Set = .horizontal) -> some View {
        modifier(ScreenPaddingModifier(edges: edges))
    }

    /// 읽기 좋은 최대 폭으로 제한하고 가운데 정렬한다.
    ///
    /// iPad 가로 모드에서 본문이 화면 전체로 늘어나는 것을 막는다.
    /// 스크롤 뷰 안쪽 콘텐츠에 적용한다.
    ///
    /// ```swift
    /// ScrollView {
    ///     VStack { ... }
    ///         .appReadableWidth()
    ///         .appScreenPadding()
    /// }
    /// ```
    func appReadableWidth(_ maxWidth: KeyPath<MetricTokens, CGFloat> = \.contentMaxWidth) -> some View {
        modifier(ReadableWidthModifier(maxWidth: maxWidth))
    }

    /// 화면 기본 배경색을 적용한다.
    func appScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }

    /// 그림자 토큰을 적용한다.
    func appShadow(_ keyPath: KeyPath<ShadowTokens, ShadowToken>) -> some View {
        modifier(ShadowTokenModifier(keyPath: keyPath))
    }
}
