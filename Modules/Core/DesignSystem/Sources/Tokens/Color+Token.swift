//
//  Color+Token.swift
//  DesignSystem
//

import SwiftUI
import UIKit

// MARK: - 리터럴 기반 색상 생성

public extension Color {
    /// `0xRRGGBB` 형태의 정수 리터럴로 색상을 만든다.
    ///
    /// 문자열 파싱(hex string)과 달리 실패 케이스가 존재하지 않으므로
    /// 옵셔널 반환이나 강제 언래핑 없이 팔레트를 정의할 수 있다.
    /// - Parameters:
    ///   - rgb: 0x000000 ~ 0xFFFFFF 범위의 RGB 값.
    ///   - opacity: 0...1 범위의 불투명도.
    init(rgb: UInt32, opacity: Double = 1) {
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - 라이트/다크 동적 색상

public extension Color {
    /// 인터페이스 스타일에 따라 런타임에 해석되는 동적 색상.
    ///
    /// 에셋 카탈로그를 쓰지 않고도 다크 모드 대응이 가능하며,
    /// 색상 정의가 코드 한곳에 모여 diff 리뷰가 쉬워진다.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// 에셋 카탈로그 색상을 안전하게 로드한다.
    ///
    /// 이름 오타나 리소스 누락은 릴리스에서 조용히 검은색으로 표시되기 쉬우므로,
    /// DEBUG 빌드에서는 `assertionFailure`로 즉시 드러내고
    /// 릴리스에서는 `fallback`으로 대체해 크래시를 피한다.
    ///
    /// - Parameter bundle: 에셋이 든 번들. 모듈화된 프로젝트에서는 에셋이 앱(`.main`)과
    ///   각 모듈 번들에 흩어져 있으므로 기본값을 두지 않고 항상 명시한다.
    static func asset(
        _ name: String,
        in bundle: Bundle,
        fallback: Color = .primary
    ) -> Color {
        guard let uiColor = UIColor(named: name, in: bundle, compatibleWith: nil) else {
            assertionFailure("에셋 카탈로그에서 \"\(name)\" 색상을 찾을 수 없습니다. (bundle: \(bundle.bundleIdentifier ?? "unknown"))")
            return fallback
        }
        return Color(uiColor: uiColor)
    }
}
