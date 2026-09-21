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

    /// 불투명한 두 색의 대비율. 1.0(동일) ~ 21.0(검정 대 흰색). 순서에 무관하다.
    ///
    /// 반투명 색은 어느 쪽이 위에 놓이는지에 따라 결과가 달라지므로 받지 않는다.
    /// 반투명 전경은 `ratio(foreground:background:in:)`를 쓴다.
    ///
    /// 반투명 색이 들어오면 디버그 빌드에서는 멈추고, 릴리스 빌드에서는 최저 대비(`1`)를 돌려준다.
    /// 알파를 무시한 부풀려진 값이 조용히 기준을 통과하는 일을 막기 위해서다.
    ///
    /// - Parameter scheme: 동적 색상을 어느 인터페이스 스타일로 해석할지.
    public static func ratio(_ first: Color, _ second: Color, in scheme: ColorScheme) -> Double {
        let firstComponents = sRGBComponents(of: first, in: scheme)
        let secondComponents = sRGBComponents(of: second, in: scheme)
        guard firstComponents.isOpaque, secondComponents.isOpaque else {
            assertionFailure("반투명 색의 대비율은 ratio(foreground:background:in:)로 계산해야 합니다.")
            return WCAG.minimumRatio
        }
        return ratio(between: firstComponents, and: secondComponents)
    }

    /// 전경을 배경 위에 합성한 뒤의 대비율.
    ///
    /// `accent.opacity(0.5)`처럼 반투명한 전경은 알파를 무시하면 대비율이 실제보다 높게 나오므로,
    /// 배경과 섞인 실제 표시 색으로 계산한다.
    ///
    /// - Returns: 배경이 반투명하면 `nil`. 그 아래 무엇이 깔리느냐에 따라 대비가 달라져 정할 수 없기 때문이다.
    ///   `overlay`처럼 반투명한 토큰이 실제로 있으므로 오류가 아니라 정상 입력으로 다룬다.
    public static func ratio(foreground: Color, background: Color, in scheme: ColorScheme) -> Double? {
        let measurement = measure(foreground: foreground, background: background, in: scheme)
        return measurement.isDeterminate ? measurement.ratio : nil
    }

    /// 합성 대비율과, 그 값을 믿을 수 있는지(배경이 불투명한지)를 함께 구한다.
    private static func measure(
        foreground: Color,
        background: Color,
        in scheme: ColorScheme
    ) -> (ratio: Double, isDeterminate: Bool) {
        let backgroundComponents = sRGBComponents(of: background, in: scheme)
        let foregroundComponents = sRGBComponents(of: foreground, in: scheme)
            .composited(over: backgroundComponents)
        return (
            ratio(between: foregroundComponents, and: backgroundComponents),
            backgroundComponents.isOpaque
        )
    }

    private static func ratio(between first: RGBComponents, and second: RGBComponents) -> Double {
        let firstLuminance = relativeLuminance(of: first)
        let secondLuminance = relativeLuminance(of: second)

        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)

        return (lighter + WCAG.flareOffset) / (darker + WCAG.flareOffset)
    }

    /// 지정한 수준을 만족하는지 판정한다. 배경이 반투명하면 판정할 수 없으므로 `false`다.
    public static func meets(
        _ level: Level,
        foreground: Color,
        background: Color,
        in scheme: ColorScheme,
        isLargeText: Bool = false
    ) -> Bool {
        let measurement = measure(foreground: foreground, background: background, in: scheme)
        return measurement.isDeterminate
            && measurement.ratio >= level.threshold(isLargeText: isLargeText)
    }

    /// 텍스트가 아닌 UI 요소(아이콘, 테두리, 그래프)의 기준을 만족하는지 판정한다.
    /// 배경이 반투명하면 판정할 수 없으므로 `false`다.
    public static func meetsNonTextRequirement(
        foreground: Color,
        background: Color,
        in scheme: ColorScheme
    ) -> Bool {
        let measurement = measure(foreground: foreground, background: background, in: scheme)
        return measurement.isDeterminate && measurement.ratio >= Level.nonTextThreshold
    }

    // MARK: - 상대 휘도

    /// WCAG 상대 휘도. 0(검정) ~ 1(흰색).
    ///
    /// 알파는 반영하지 않는다. 반투명 색은 배경에 따라 휘도가 달라지기 때문이다.
    /// 반투명 입력을 다루는 방식이 공개 API마다 달라지지 않도록 모듈 안(대비율 계산·테스트)에서만 쓴다.
    static func relativeLuminance(of color: Color, in scheme: ColorScheme) -> Double {
        relativeLuminance(of: sRGBComponents(of: color, in: scheme))
    }

    private static func relativeLuminance(of components: RGBComponents) -> Double {
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

        /// 대비율의 최저값(같은 색끼리). 계산할 수 없는 입력은 어떤 기준도 통과하지 않도록 이 값으로 처리한다.
        static let minimumRatio: Double = 1.0

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
        var alpha: Double = 1

        /// 에셋 카탈로그나 색 공간 변환을 거치면 불투명 색의 알파가 `0.99999994`처럼 나올 수 있어 오차를 둔다.
        var isOpaque: Bool {
            alpha >= 1 - Self.opaqueTolerance
        }

        private static let opaqueTolerance: Double = 1e-4

        /// 불투명한 배경 위에 올렸을 때 보이는 색. WCAG 도구들처럼 sRGB 값에서 섞는다.
        func composited(over background: RGBComponents) -> RGBComponents {
            func blend(_ top: Double, _ bottom: Double) -> Double {
                top * alpha + bottom * (1 - alpha)
            }
            return RGBComponents(
                red: blend(red, background.red),
                green: blend(green, background.green),
                blue: blend(blue, background.blue)
            )
        }
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
                return RGBComponents(red: white, green: white, blue: white, alpha: alpha)
            }
            assertionFailure("색상을 RGB 성분으로 분해할 수 없습니다: \(resolved)")
            return RGBComponents(red: 0, green: 0, blue: 0)
        }

        return RGBComponents(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - 진단용 요약

public extension ColorContrast {
    /// 대비 검사 결과. 카탈로그 표시와 테스트 실패 메시지에 함께 쓴다.
    struct Report: CustomStringConvertible {
        public let name: String
        /// 합성 대비율. 배경이 반투명해 확정할 수 없으면 `nil`이다.
        ///
        /// 잘못된 수치가 화면에 그대로 표시되지 않도록 판정 불가일 때는 값을 두지 않는다.
        public let ratio: Double?
        public let scheme: ColorScheme
        public let threshold: Double

        /// 배경이 불투명해 대비율을 확정할 수 있었는지. 반투명 배경이면 `false`이고 통과로 보지 않는다.
        public var isDeterminate: Bool {
            ratio != nil
        }

        public var passes: Bool {
            guard let ratio else { return false }
            return ratio >= threshold
        }

        /// 표시용 판정. "기준 미달"과 "반투명 배경이라 판정 불가"를 구분해 보여 주기 위해 쓴다.
        public enum Verdict {
            case pass
            case fail
            case indeterminate
        }

        public var verdict: Verdict {
            guard isDeterminate else { return .indeterminate }
            return passes ? .pass : .fail
        }

        /// 표시용 대비율(`4.54`). 판정 불가면 `—`.
        public var formattedRatio: String {
            guard let ratio else { return Format.indeterminate }
            return String(format: Format.ratio, ratio)
        }

        public var description: String {
            let schemeName = scheme == .dark ? "dark" : "light"
            guard isDeterminate else {
                return "\(name) [\(schemeName)] 판정 불가 (반투명 배경)"
            }
            return "\(name) [\(schemeName)] \(formattedRatio):1 (기준 \(threshold):1) \(passes ? "통과" : "미달")"
        }

        private enum Format {
            static let ratio = "%.2f"
            static let indeterminate = "—"
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
        let measurement = measure(foreground: foreground, background: background, in: scheme)
        return Report(
            name: name,
            ratio: measurement.isDeterminate ? measurement.ratio : nil,
            scheme: scheme,
            threshold: threshold
        )
    }
}
