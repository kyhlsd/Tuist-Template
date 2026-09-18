//
//  Theme.swift
//  DesignSystem
//

import SwiftUI

// MARK: - Theme

/// 색상 / 타이포그래피 / 메트릭 토큰의 묶음.
///
/// 값 타입이므로 화이트라벨 앱, 이벤트 테마, 접근성 고대비 모드 등을
/// 인스턴스 교체만으로 지원할 수 있다.
public struct Theme {
    public init(
        colors: ColorTokens,
        typography: TypographyTokens,
        metrics: MetricTokens
    ) {
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
    }

    public var colors: ColorTokens
    public var typography: TypographyTokens
    public var metrics: MetricTokens

    public static let standard = Theme(
        colors: .standard,
        typography: .standard,
        metrics: .standard
    )
}

public extension EnvironmentValues {
    @Entry var theme: Theme = .standard
}

public extension View {
    /// 하위 뷰 계층에 테마를 주입한다. 앱 진입점이나 프리뷰에서 호출한다.
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}

// MARK: - 토큰 접근 헬퍼

public extension Theme {
    func color(_ keyPath: KeyPath<ColorTokens, Color>) -> Color {
        colors[keyPath: keyPath]
    }

    func spacing(_ keyPath: KeyPath<SpacingTokens, CGFloat>) -> CGFloat {
        metrics.spacing[keyPath: keyPath]
    }

    func radius(_ keyPath: KeyPath<RadiusTokens, CGFloat>) -> CGFloat {
        metrics.radius[keyPath: keyPath]
    }
}
