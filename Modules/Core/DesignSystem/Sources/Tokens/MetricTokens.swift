//
//  MetricTokens.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 개별 스케일

/// 4pt 그리드 기반 여백 스케일.
public struct SpacingTokens {
    public init(
        xxs: CGFloat,
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        lg: CGFloat,
        xl: CGFloat,
        xxl: CGFloat,
        xxxl: CGFloat,
        screenHorizontal: CGFloat,
        screenHorizontalRegular: CGFloat
    ) {
        self.xxs = xxs
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
        self.xxxl = xxxl
        self.screenHorizontal = screenHorizontal
        self.screenHorizontalRegular = screenHorizontalRegular
    }

    public var xxs: CGFloat
    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    public var xxl: CGFloat
    public var xxxl: CGFloat

    /// 컴팩트 폭(대부분의 iPhone)에서의 화면 좌우 여백.
    public var screenHorizontal: CGFloat
    /// 레귤러 폭(iPad, 가로 모드)에서의 화면 좌우 여백.
    ///
    /// 화면이 넓어지면 여백도 함께 늘어나야 콘텐츠가 가장자리에 붙지 않는다.
    public var screenHorizontalRegular: CGFloat
}

public struct RadiusTokens {
    public init(
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        lg: CGFloat,
        xl: CGFloat,
        full: CGFloat
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.full = full
    }

    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    /// 캡슐 형태를 위한 충분히 큰 값.
    public var full: CGFloat
}

public struct BorderTokens {
    public init(
        hairline: CGFloat,
        regular: CGFloat,
        thick: CGFloat,
        focus: CGFloat
    ) {
        self.hairline = hairline
        self.regular = regular
        self.thick = thick
        self.focus = focus
    }

    /// 1px 대응 두께. 레티나에서 얇은 선을 표현할 때 사용한다.
    public var hairline: CGFloat
    public var regular: CGFloat
    public var thick: CGFloat
    /// 포커스 링 두께.
    public var focus: CGFloat
}

public struct IconSizeTokens {
    public init(
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        lg: CGFloat,
        xl: CGFloat
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
    }

    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
}

public struct ShadowToken: Equatable {
    public init(
        color: Color,
        radius: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }

    public var color: Color
    public var radius: CGFloat
    public var x: CGFloat
    public var y: CGFloat

    public static let none = ShadowToken(color: .clear, radius: 0, x: 0, y: 0)
}

public struct ShadowTokens {
    public init(
        card: ShadowToken,
        floating: ShadowToken,
        modal: ShadowToken
    ) {
        self.card = card
        self.floating = floating
        self.modal = modal
    }

    public var card: ShadowToken
    public var floating: ShadowToken
    public var modal: ShadowToken
}

public struct DurationTokens {
    public init(
        instant: Double,
        fast: Double,
        normal: Double,
        slow: Double
    ) {
        self.instant = instant
        self.fast = fast
        self.normal = normal
        self.slow = slow
    }

    public var instant: Double
    public var fast: Double
    public var normal: Double
    public var slow: Double
}

// MARK: - 통합 메트릭

public struct MetricTokens {
    public init(
        spacing: SpacingTokens,
        radius: RadiusTokens,
        border: BorderTokens,
        icon: IconSizeTokens,
        shadow: ShadowTokens,
        duration: DurationTokens,
        minimumHitTarget: CGFloat,
        contentMaxWidth: CGFloat,
        formMaxWidth: CGFloat
    ) {
        self.spacing = spacing
        self.radius = radius
        self.border = border
        self.icon = icon
        self.shadow = shadow
        self.duration = duration
        self.minimumHitTarget = minimumHitTarget
        self.contentMaxWidth = contentMaxWidth
        self.formMaxWidth = formMaxWidth
    }

    public var spacing: SpacingTokens
    public var radius: RadiusTokens
    public var border: BorderTokens
    public var icon: IconSizeTokens
    public var shadow: ShadowTokens
    public var duration: DurationTokens

    /// HIG 권장 최소 터치 영역.
    public var minimumHitTarget: CGFloat

    /// 본문이 차지할 수 있는 최대 폭.
    ///
    /// iPad 가로 모드에서 텍스트가 화면 전체로 늘어나면 한 줄이 100자를 넘어
    /// 시선이 다음 줄 첫 글자를 찾지 못한다. 조판에서 권장하는 45~75자 범위에
    /// 맞추기 위한 상한이다.
    public var contentMaxWidth: CGFloat

    /// 폼·다이얼로그 등 입력 중심 콘텐츠의 최대 폭. 본문보다 좁게 잡는다.
    public var formMaxWidth: CGFloat
}

public extension MetricTokens {
    static let standard = MetricTokens(
        spacing: SpacingTokens(
            xxs: 2, xs: 4, sm: 8, md: 12, lg: 16,
            xl: 24, xxl: 32, xxxl: 48,
            screenHorizontal: 20,
            screenHorizontalRegular: 40
        ),
        radius: RadiusTokens(xs: 4, sm: 8, md: 12, lg: 16, xl: 24, full: 999),
        border: BorderTokens(hairline: 1 / 3, regular: 1, thick: 2, focus: 3),
        icon: IconSizeTokens(xs: 12, sm: 16, md: 20, lg: 24, xl: 32),
        shadow: ShadowTokens(
            card: ShadowToken(color: ColorPalette.black.opacity(0.06), radius: 8, x: 0, y: 2),
            floating: ShadowToken(color: ColorPalette.black.opacity(0.12), radius: 16, x: 0, y: 6),
            modal: ShadowToken(color: ColorPalette.black.opacity(0.20), radius: 32, x: 0, y: 12)
        ),
        duration: DurationTokens(instant: 0.1, fast: 0.18, normal: 0.28, slow: 0.45),
        minimumHitTarget: 44,
        contentMaxWidth: 680,
        formMaxWidth: 480
    )
}

// MARK: - 애니메이션 프리셋

public extension Animation {
    static func app(_ duration: Double) -> Animation {
        .easeOut(duration: duration)
    }

    static func appSpring(response: Double = 0.35, damping: Double = 0.8) -> Animation {
        .spring(response: response, dampingFraction: damping)
    }
}
