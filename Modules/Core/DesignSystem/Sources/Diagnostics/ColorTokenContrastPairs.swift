//
//  ColorTokenContrastPairs.swift
//  DesignSystem
//

import SwiftUI

/// 대비 검사를 수행할 토큰 조합 목록.
///
/// 테스트와 진단 프리뷰가 같은 목록을 참조해야, 테스트가 실패했을 때
/// 프리뷰에서 곧바로 원인을 확인할 수 있다.
public enum ColorTokenContrastPairs {
    /// 검사할 전경·배경 토큰 한 쌍과 통과 기준.
    public struct Pair {
        public let name: String
        public let foreground: KeyPath<ColorTokens, Color>
        public let background: KeyPath<ColorTokens, Color>
        public let threshold: Double

        public init(
            name: String,
            foreground: KeyPath<ColorTokens, Color>,
            background: KeyPath<ColorTokens, Color>,
            threshold: Double
        ) {
            self.name = name
            self.foreground = foreground
            self.background = background
            self.threshold = threshold
        }

        /// 아래 목록을 표처럼 한 줄씩 적기 위한 축약형.
        init(
            _ name: String,
            _ foreground: KeyPath<ColorTokens, Color>,
            _ background: KeyPath<ColorTokens, Color>,
            _ threshold: Double
        ) {
            self.init(name: name, foreground: foreground, background: background, threshold: threshold)
        }
    }

    private static let normalText = ColorContrast.Level.aa.threshold(isLargeText: false)
    private static let largeText = ColorContrast.Level.aa.threshold(isLargeText: true)
    private static let nonText = ColorContrast.Level.nonTextThreshold

    /// 본문 텍스트. 가장 엄격한 기준을 적용한다.
    public static let text: [Pair] = [
        Pair("textPrimary / background", \.textPrimary, \.background, normalText),
        Pair("textPrimary / surface", \.textPrimary, \.surface, normalText),
        Pair("textSecondary / background", \.textSecondary, \.background, normalText),
        Pair("textSecondary / surface", \.textSecondary, \.surface, normalText),
        Pair("onAccent / accent", \.onAccent, \.accent, normalText),
        Pair("onAccent / accentPressed", \.onAccent, \.accentPressed, normalText),
    ]

    /// 상태 색. 배지·배너처럼 옅은 배경 위에 놓인다.
    public static let status: [Pair] = [
        Pair("success / successSubtle", \.success, \.successSubtle, normalText),
        Pair("warning / warningSubtle", \.warning, \.warningSubtle, normalText),
        Pair("danger / dangerSubtle", \.danger, \.dangerSubtle, normalText),
        Pair("info / infoSubtle", \.info, \.infoSubtle, normalText),
        Pair("accent / accentSubtle", \.accent, \.accentSubtle, normalText),
    ]

    /// 보조 텍스트와 비텍스트 요소. 완화된 기준을 적용한다.
    public static let supporting: [Pair] = [
        Pair("textTertiary / background", \.textTertiary, \.background, largeText),
        Pair("borderStrong / surface", \.borderStrong, \.surface, nonText),
        Pair("accent / background", \.accent, \.background, nonText),
        Pair("danger / background", \.danger, \.background, nonText),
    ]

    public static var all: [Pair] {
        text + status + supporting
    }
}
