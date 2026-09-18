//
//  ColorTokens.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 1단계: 원시 팔레트 (Primitive)

/// 브랜드가 보유한 원색 목록.
///
/// 화면 코드는 직접 참조하지 않는다. 항상 아래 `ColorTokens`의 시맨틱 토큰만
/// 사용해야 팔레트 교체 시 영향 범위가 이 파일로 한정된다.
/// 그래서 모듈 밖으로 공개하지 않는다. 규칙을 문서가 아니라 컴파일러가 지킨다.
/// 다른 팔레트가 필요한 테마는 `ColorTokens` 를 직접 구성한다.
enum ColorPalette {
    // Neutral
    static let neutral0 = Color(rgb: 0xFFFFFF)
    static let neutral50 = Color(rgb: 0xF7F8FA)
    static let neutral100 = Color(rgb: 0xEDEFF3)
    static let neutral200 = Color(rgb: 0xDCE0E8)
    static let neutral300 = Color(rgb: 0xB0B8C4)
    static let neutral400 = Color(rgb: 0x7B8494)
    static let neutral500 = Color(rgb: 0x6B7484)
    static let neutral600 = Color(rgb: 0x4A5262)
    static let neutral700 = Color(rgb: 0x2A2F3A)
    static let neutral800 = Color(rgb: 0x1A1E26)
    static let neutral900 = Color(rgb: 0x0E1116)

    // Brand
    static let brand100 = Color(rgb: 0xE3ECFE)
    static let brand200 = Color(rgb: 0xB9CCF8)
    static let brand300 = Color(rgb: 0x7BA8FF)
    static let brand400 = Color(rgb: 0x4C8DFF)
    static let brand500 = Color(rgb: 0x1557D8)
    static let brand600 = Color(rgb: 0x0F429F)
    static let brand900 = Color(rgb: 0x1C2C4D)
    static let brand950 = Color(rgb: 0x16233D)

    // Status
    static let greenSubtle = Color(rgb: 0xE3F7EF)
    static let greenSubtleDark = Color(rgb: 0x10352A)
    static let greenLight = Color(rgb: 0x3ED9A3)
    static let green = Color(rgb: 0x0F7A55)

    static let amberSubtle = Color(rgb: 0xFFF3DC)
    static let amberSubtleDark = Color(rgb: 0x3A2A0E)
    static let amberLight = Color(rgb: 0xFFB84D)
    static let amber = Color(rgb: 0xA35C00)

    static let redSubtle = Color(rgb: 0xFDE8E7)
    static let redSubtleDark = Color(rgb: 0x3A1614)
    static let redLight = Color(rgb: 0xFF6B62)
    static let red = Color(rgb: 0xC41E17)

    static let black = Color(rgb: 0x000000)
}

// MARK: - 2단계: 시맨틱 토큰 (Semantic)

/// 역할 기반 색상 토큰.
///
/// 값 타입이므로 테마별 인스턴스를 만들어 `Theme`에 주입할 수 있다.
public struct ColorTokens {
    public init(
        background: Color,
        backgroundElevated: Color,
        surface: Color,
        surfacePressed: Color,
        surfaceMuted: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        textDisabled: Color,
        border: Color,
        borderStrong: Color,
        separator: Color,
        accent: Color,
        accentPressed: Color,
        accentDisabled: Color,
        accentSubtle: Color,
        onAccent: Color,
        success: Color,
        successSubtle: Color,
        warning: Color,
        warningSubtle: Color,
        danger: Color,
        dangerSubtle: Color,
        info: Color,
        infoSubtle: Color,
        overlay: Color,
        controlKnob: Color
    ) {
        self.background = background
        self.backgroundElevated = backgroundElevated
        self.surface = surface
        self.surfacePressed = surfacePressed
        self.surfaceMuted = surfaceMuted
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.textDisabled = textDisabled
        self.border = border
        self.borderStrong = borderStrong
        self.separator = separator
        self.accent = accent
        self.accentPressed = accentPressed
        self.accentDisabled = accentDisabled
        self.accentSubtle = accentSubtle
        self.onAccent = onAccent
        self.success = success
        self.successSubtle = successSubtle
        self.warning = warning
        self.warningSubtle = warningSubtle
        self.danger = danger
        self.dangerSubtle = dangerSubtle
        self.info = info
        self.infoSubtle = infoSubtle
        self.overlay = overlay
        self.controlKnob = controlKnob
    }

    // Surface
    public var background: Color
    public var backgroundElevated: Color
    public var surface: Color
    public var surfacePressed: Color
    /// 비활성/보조 영역 배경.
    public var surfaceMuted: Color

    // Content
    public var textPrimary: Color
    public var textSecondary: Color
    public var textTertiary: Color
    public var textDisabled: Color

    // Line
    public var border: Color
    public var borderStrong: Color
    public var separator: Color

    // Interactive
    public var accent: Color
    public var accentPressed: Color
    public var accentDisabled: Color
    public var accentSubtle: Color
    /// 강조색 위에 놓이는 콘텐츠 색.
    ///
    /// 라이트에서는 짙은 파랑 위 흰 글자, 다크에서는 밝은 파랑 위 어두운 글자가 된다.
    /// 다크 모드 강조색을 어둡게 만들면 어두운 배경과 구분되지 않으므로,
    /// 강조색을 밝게 유지하고 그 위 글자색을 뒤집는 편이 대비를 확보하기 쉽다.
    public var onAccent: Color

    // Status
    public var success: Color
    public var successSubtle: Color
    public var warning: Color
    public var warningSubtle: Color
    public var danger: Color
    public var dangerSubtle: Color
    public var info: Color
    public var infoSubtle: Color

    /// Etc
    public var overlay: Color
    /// 컨트롤 손잡이처럼 라이트/다크 모두 동일하게 유지되는 색.
    public var controlKnob: Color
}

public extension ColorTokens {
    /// 라이트/다크를 동시에 지원하는 기본 토큰 세트.
    static let standard = ColorTokens(
        background: Color(light: ColorPalette.neutral50, dark: ColorPalette.neutral900),
        backgroundElevated: Color(light: ColorPalette.neutral0, dark: ColorPalette.neutral800),
        surface: Color(light: ColorPalette.neutral0, dark: ColorPalette.neutral800),
        surfacePressed: Color(light: ColorPalette.neutral100, dark: ColorPalette.neutral700),
        surfaceMuted: Color(light: ColorPalette.neutral100, dark: ColorPalette.neutral700),

        textPrimary: Color(light: ColorPalette.neutral800, dark: ColorPalette.neutral50),
        textSecondary: Color(light: ColorPalette.neutral600, dark: ColorPalette.neutral300),
        textTertiary: Color(light: ColorPalette.neutral400, dark: ColorPalette.neutral400),
        textDisabled: Color(light: ColorPalette.neutral300, dark: ColorPalette.neutral600),

        border: Color(light: ColorPalette.neutral200, dark: ColorPalette.neutral700),
        borderStrong: Color(light: ColorPalette.neutral400, dark: ColorPalette.neutral500),
        separator: Color(light: ColorPalette.neutral100, dark: ColorPalette.neutral700),

        accent: Color(light: ColorPalette.brand500, dark: ColorPalette.brand400),
        accentPressed: Color(light: ColorPalette.brand600, dark: ColorPalette.brand300),
        accentDisabled: Color(light: ColorPalette.brand200, dark: ColorPalette.brand900),
        accentSubtle: Color(light: ColorPalette.brand100, dark: ColorPalette.brand950),
        onAccent: Color(light: ColorPalette.neutral0, dark: ColorPalette.neutral900),

        success: Color(light: ColorPalette.green, dark: ColorPalette.greenLight),
        successSubtle: Color(light: ColorPalette.greenSubtle, dark: ColorPalette.greenSubtleDark),
        warning: Color(light: ColorPalette.amber, dark: ColorPalette.amberLight),
        warningSubtle: Color(light: ColorPalette.amberSubtle, dark: ColorPalette.amberSubtleDark),
        danger: Color(light: ColorPalette.red, dark: ColorPalette.redLight),
        dangerSubtle: Color(light: ColorPalette.redSubtle, dark: ColorPalette.redSubtleDark),
        info: Color(light: ColorPalette.brand500, dark: ColorPalette.brand400),
        infoSubtle: Color(light: ColorPalette.brand100, dark: ColorPalette.brand950),

        overlay: Color(
            light: ColorPalette.black.opacity(0.4),
            dark: ColorPalette.black.opacity(0.6)
        ),
        controlKnob: ColorPalette.neutral0
    )
}
