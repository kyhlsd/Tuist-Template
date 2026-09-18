//
//  ColorContrast.swift
//  DesignSystem
//

import SwiftUI
import UIKit

/// WCAG 기준 색 대비율을 계산한다.
///
/// 팔레트를 바꿀 때 접근성 회귀를 자동으로 잡기 위한 도구다.
/// 눈으로는 충분해 보이는 조합도 수치로 재 보면 기준에 못 미치는 경우가 많다.
public enum ColorContrast {
    /// WCAG 준수 수준.
    public enum Level {
        /// 최소 기준. 대부분의 서비스가 목표로 한다.
        case aa
        /// 강화 기준. 공공 서비스나 고령층 대상 서비스에서 요구되기도 한다.
        case aaa

        /// - Parameter isLargeText: 18pt 이상(굵은 글씨는 14pt 이상)이면 `true`.
        public func threshold(isLargeText: Bool) -> Double {
            switch self {
            case .aa: isLargeText ? WCAG.aaLargeText : WCAG.aaText
            case .aaa: isLargeText ? WCAG.aaaLargeText : WCAG.aaaText
            }
        }

        /// 아이콘·테두리 등 텍스트가 아닌 UI 요소의 최소 대비율.
        public static let nonTextThreshold: Double = WCAG.nonText
    }

    /// 두 색의 대비율. 1.0(동일) ~ 21.0(검정 대 흰색).
    ///
    /// - Parameter scheme: 동적 색상을 어느 인터페이스 스타일로 해석할지.
    public static func ratio(_ first: Color, _ second: Color, in scheme: ColorScheme) -> Double {
        let firstLuminance = relativeLuminance(of: first, in: scheme)
        let secondLuminance = relativeLuminance(of: second, in: scheme)

        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)

        return (lighter + WCAG.flareOffset) / (darker + WCAG.flareOffset)
    }

    /// 지정한 수준을 만족하는지 판정한다.
    public static func meets(
        _ level: Level,
        foreground: Color,
        background: Color,
        in scheme: ColorScheme,
        isLargeText: Bool = false
    ) -> Bool {
        ratio(foreground, background, in: scheme) >= level.threshold(isLargeText: isLargeText)
    }

    /// 텍스트가 아닌 UI 요소(아이콘, 테두리, 그래프)의 기준을 만족하는지 판정한다.
    public static func meetsNonTextRequirement(
        foreground: Color,
        background: Color,
        in scheme: ColorScheme
    ) -> Bool {
        ratio(foreground, background, in: scheme) >= Level.nonTextThreshold
    }

    // MARK: - 상대 휘도

    /// WCAG 상대 휘도. 0(검정) ~ 1(흰색).
    public static func relativeLuminance(of color: Color, in scheme: ColorScheme) -> Double {
        let components = sRGBComponents(of: color, in: scheme)

        // 감마 보정을 되돌려 선형 값으로 만든 뒤 사람 눈의 채널별 민감도로 가중한다.
        let red = linearized(components.red)
        let green = linearized(components.green)
        let blue = linearized(components.blue)

        return WCAG.redWeight * red + WCAG.greenWeight * green + WCAG.blueWeight * blue
    }

    private static func linearized(_ channel: Double) -> Double {
        channel <= WCAG.linearThreshold
            ? channel / WCAG.linearDivisor
            : pow((channel + WCAG.gammaOffset) / (1 + WCAG.gammaOffset), WCAG.gamma)
    }

    /// WCAG 2.x 명세의 상수. 값을 바꾸면 명세와 달라지므로 손대지 않는다.
    /// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
    private enum WCAG {
        // 대비율 기준 (SC 1.4.3, 1.4.6, 1.4.11)
        static let aaText: Double = 4.5
        static let aaLargeText: Double = 3.0
        static let aaaText: Double = 7.0
        static let aaaLargeText: Double = 4.5
        static let nonText: Double = 3.0

        /// 대비율 계산 시 양쪽 휘도에 더하는 값(주변광 반사 보정).
        static let flareOffset: Double = 0.05

        // 상대 휘도의 채널 가중치
        static let redWeight: Double = 0.2126
        static let greenWeight: Double = 0.7152
        static let blueWeight: Double = 0.0722

        // sRGB 감마 해제
        static let linearThreshold: Double = 0.03928
        static let linearDivisor: Double = 12.92
        static let gammaOffset: Double = 0.055
        static let gamma: Double = 2.4
    }

    // MARK: - 색 분해

    private struct RGBComponents {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// 동적 색상을 지정한 인터페이스 스타일로 해석해 sRGB 성분을 얻는다.
    private static func sRGBComponents(of color: Color, in scheme: ColorScheme) -> RGBComponents {
        let traits = UITraitCollection(
            userInterfaceStyle: scheme == .dark ? .dark : .light
        )
        let resolved = UIColor(color).resolvedColor(with: traits)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // 그레이스케일 등 RGB로 바로 분해되지 않는 색 공간을 대비해 반환값을 확인한다.
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            var white: CGFloat = 0
            if resolved.getWhite(&white, alpha: &alpha) {
                return RGBComponents(red: white, green: white, blue: white)
            }
            assertionFailure("색상을 RGB 성분으로 분해할 수 없습니다: \(resolved)")
            return RGBComponents(red: 0, green: 0, blue: 0)
        }

        return RGBComponents(red: red, green: green, blue: blue)
    }
}

// MARK: - 진단용 요약

public extension ColorContrast {
    /// 대비 검사 결과. 카탈로그 표시와 테스트 실패 메시지에 함께 쓴다.
    struct Report: CustomStringConvertible {
        public let name: String
        public let ratio: Double
        public let scheme: ColorScheme
        public let threshold: Double

        public var passes: Bool {
            ratio >= threshold
        }

        public var description: String {
            let schemeName = scheme == .dark ? "dark" : "light"
            let formatted = String(format: "%.2f", ratio)
            return "\(name) [\(schemeName)] \(formatted):1 (기준 \(threshold):1) \(passes ? "통과" : "미달")"
        }
    }

    /// 전경/배경 한 쌍을 검사해 결과를 만든다.
    static func report(
        name: String,
        foreground: Color,
        background: Color,
        in scheme: ColorScheme,
        threshold: Double = Level.aa.threshold(isLargeText: false)
    ) -> Report {
        Report(
            name: name,
            ratio: ratio(foreground, background, in: scheme),
            scheme: scheme,
            threshold: threshold
        )
    }
}
