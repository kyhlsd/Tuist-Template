//
//  TypographyTokens.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 폰트 토큰

/// 하나의 텍스트 스타일을 서술하는 값 타입.
///
/// `textStyle`은 Dynamic Type 스케일링의 기준이 되며,
/// `lineHeight`는 디자인 시안의 행간(px)을 그대로 옮겨 적기 위한 값이다.
public struct FontToken: Hashable {
    public var size: CGFloat
    public var weight: Font.Weight
    /// Dynamic Type 스케일 기준. 접근성 설정에 따라 `size`가 이 스타일 비율로 확대된다.
    public var textStyle: Font.TextStyle
    /// 시안상의 행간. `size`와 같으면 추가 행간 없이 렌더링된다.
    public var lineHeight: CGFloat
    public var tracking: CGFloat = 0
    public var design: Font.Design = .default

    /// - Parameter lineHeightMultiple: 글자 크기 대비 행간 배수. 시안의 행간(px)이 아니라 비율로 받는다.
    public init(
        size: CGFloat,
        weight: Font.Weight,
        textStyle: Font.TextStyle,
        lineHeightMultiple: CGFloat = 1.4,
        tracking: CGFloat = 0,
        design: Font.Design = .default
    ) {
        self.size = size
        self.weight = weight
        self.textStyle = textStyle
        lineHeight = (size * lineHeightMultiple).rounded()
        self.tracking = tracking
        self.design = design
    }
}

// MARK: - 폰트 공급자

/// 실제 `Font` 인스턴스를 만드는 책임을 분리한다.
///
/// 시스템 폰트 → 커스텀 폰트 전환 시 토큰 정의는 그대로 두고
/// 구현체만 교체하면 된다.
public protocol FontProviding {
    func font(size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font
}

/// San Francisco 기본 구현.
public struct SystemFontProvider: FontProviding {
    public init() {}
    public func font(size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

/// 커스텀 폰트 구현.
///
/// 굵기별 PostScript 이름을 클로저로 주입받아 하드코딩된 문자열이
/// 뷰 코드로 새어 나가지 않게 한다.
public struct CustomFontProvider: FontProviding {
    public init(
        postScriptName: @escaping (Font.Weight) -> String
    ) {
        self.postScriptName = postScriptName
    }

    /// 예: `{ weight in weight >= .semibold ? "Pretendard-SemiBold" : "Pretendard-Regular" }`
    public let postScriptName: (Font.Weight) -> String

    public func font(size: CGFloat, weight: Font.Weight, design _: Font.Design) -> Font {
        // 스케일링은 상위 ScaledMetric에서 이미 적용되므로 fixedSize로 생성한다.
        .custom(postScriptName(weight), fixedSize: size)
    }
}

// MARK: - 타이포그래피 스케일

public struct TypographyTokens {
    public init(
        display: FontToken,
        titleLarge: FontToken,
        titleMedium: FontToken,
        titleSmall: FontToken,
        bodyLarge: FontToken,
        bodyMedium: FontToken,
        bodySmall: FontToken,
        label: FontToken,
        caption: FontToken,
        provider: any FontProviding
    ) {
        self.display = display
        self.titleLarge = titleLarge
        self.titleMedium = titleMedium
        self.titleSmall = titleSmall
        self.bodyLarge = bodyLarge
        self.bodyMedium = bodyMedium
        self.bodySmall = bodySmall
        self.label = label
        self.caption = caption
        self.provider = provider
    }

    public var display: FontToken
    public var titleLarge: FontToken
    public var titleMedium: FontToken
    public var titleSmall: FontToken
    public var bodyLarge: FontToken
    public var bodyMedium: FontToken
    public var bodySmall: FontToken
    public var label: FontToken
    public var caption: FontToken

    public var provider: any FontProviding
}

public extension TypographyTokens {
    static let standard = TypographyTokens(
        display: FontToken(size: 32, weight: .bold, textStyle: .largeTitle, lineHeightMultiple: 1.25, tracking: -0.4),
        titleLarge: FontToken(size: 26, weight: .bold, textStyle: .title, lineHeightMultiple: 1.3, tracking: -0.3),
        titleMedium: FontToken(size: 20, weight: .semibold, textStyle: .title2, lineHeightMultiple: 1.35),
        titleSmall: FontToken(size: 17, weight: .semibold, textStyle: .title3, lineHeightMultiple: 1.4),
        bodyLarge: FontToken(size: 17, weight: .regular, textStyle: .body, lineHeightMultiple: 1.5),
        bodyMedium: FontToken(size: 15, weight: .regular, textStyle: .callout, lineHeightMultiple: 1.5),
        bodySmall: FontToken(size: 13, weight: .regular, textStyle: .subheadline, lineHeightMultiple: 1.45),
        label: FontToken(size: 15, weight: .semibold, textStyle: .headline, lineHeightMultiple: 1.2),
        caption: FontToken(size: 12, weight: .medium, textStyle: .caption, lineHeightMultiple: 1.3),
        provider: SystemFontProvider()
    )
}
