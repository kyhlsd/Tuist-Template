//
//  DesignTokenTests.swift
//  DesignSystemTests
//
//  ⚠️ 이 파일은 테스트 타깃에 포함해야 한다. 모듈 이름은 프로젝트에 맞게 수정한다.
//

@testable import DesignSystem
import SwiftUI
import Testing

// MARK: - 색 대비

@Suite("색 대비 (WCAG AA)")
@MainActor
struct ColorContrastTests {
    private let theme = Theme.standard

    /// 팔레트를 수정했을 때 접근성 회귀를 CI에서 막는다.
    ///
    /// 눈으로는 충분해 보이는 조합도 수치로는 기준에 못 미치는 경우가 많고,
    /// 특히 다크 모드에서 옅은 배경 위 상태 색이 자주 미달한다.
    @Test(
        "모든 토큰 조합이 기준 대비율을 만족한다",
        arguments: [ColorScheme.light, ColorScheme.dark]
    )
    func tokenPairsMeetContrastRequirement(scheme: ColorScheme) {
        let failures = ColorTokenContrastPairs.all.compactMap { pair -> String? in
            let report = ColorContrast.report(
                name: pair.name,
                foreground: theme.colors[keyPath: pair.foreground],
                background: theme.colors[keyPath: pair.background],
                in: scheme,
                threshold: pair.threshold
            )
            return report.passes ? nil : report.description
        }

        #expect(failures.isEmpty, "대비 기준 미달:\n\(failures.joined(separator: "\n"))")
    }

    @Test("대비율 계산이 알려진 값과 일치한다")
    func ratioMatchesKnownValues() {
        // 검정 대 흰색은 WCAG가 정의한 최대값 21:1이다.
        let maximum = ColorContrast.ratio(.black, .white, in: .light)
        #expect(abs(maximum - 21.0) < 0.01)

        // 같은 색끼리는 1:1이다.
        let identical = ColorContrast.ratio(.blue, .blue, in: .light)
        #expect(abs(identical - 1.0) < 0.01)
    }

    @Test("대비율은 순서에 무관하다")
    func ratioIsSymmetric() {
        let forward = ColorContrast.ratio(
            theme.colors.textPrimary,
            theme.colors.background,
            in: .light
        )
        let backward = ColorContrast.ratio(
            theme.colors.background,
            theme.colors.textPrimary,
            in: .light
        )

        #expect(abs(forward - backward) < 0.0001)
    }

    @Test("라이트와 다크가 서로 다른 색으로 해석된다")
    func dynamicColorsResolveDifferently() {
        let light = ColorContrast.relativeLuminance(of: theme.colors.background, in: .light)
        let dark = ColorContrast.relativeLuminance(of: theme.colors.background, in: .dark)

        #expect(light > dark, "라이트 모드 배경이 다크 모드보다 밝아야 한다")
    }
}

// MARK: - 아이콘

@Suite("아이콘")
struct AppIconTests {
    /// SF Symbol 이름 오타나 OS 버전별 누락을 잡는다.
    ///
    /// 심볼이 없으면 빌드는 통과하고 런타임에 빈 이미지가 표시되므로
    /// 코드 리뷰로는 걸러지지 않는다.
    @Test("모든 아이콘이 현재 OS에서 렌더링 가능하다")
    func allIconsAreAvailable() {
        let unavailable = AppIcon.unavailableIcons

        #expect(
            unavailable.isEmpty,
            "사용할 수 없는 심볼: \(unavailable.map(\.systemName).joined(separator: ", "))"
        )
    }

    @Test("아이콘 이름이 중복되지 않는다")
    func iconNamesAreUnique() {
        let names = AppIcon.allCases.map(\.systemName)
        let unique = Set(names)

        #expect(names.count == unique.count, "중복된 심볼 이름이 있습니다")
    }
}

// MARK: - 스케일 일관성

@Suite("토큰 스케일")
struct TokenScaleTests {
    private let metrics = MetricTokens.standard
    private let typography = TypographyTokens.standard

    @Test("여백 스케일이 단조 증가한다")
    func spacingScaleIsMonotonic() {
        let spacing = metrics.spacing
        let values: [CGFloat] = [
            spacing.xxs, spacing.xs, spacing.sm, spacing.md,
            spacing.lg, spacing.xl, spacing.xxl, spacing.xxxl,
        ]

        #expect(values == values.sorted(), "여백 스케일 순서가 어긋났습니다: \(values)")
    }

    @Test("모서리 반경 스케일이 단조 증가한다")
    func radiusScaleIsMonotonic() {
        let radius = metrics.radius
        let values: [CGFloat] = [radius.xs, radius.sm, radius.md, radius.lg, radius.xl]

        #expect(values == values.sorted())
    }

    @Test("타이포그래피 스케일이 역순으로 정렬된다")
    func typographyScaleIsOrdered() {
        let sizes: [CGFloat] = [
            typography.display.size,
            typography.titleLarge.size,
            typography.titleMedium.size,
            typography.bodyLarge.size,
            typography.bodySmall.size,
            typography.caption.size,
        ]

        #expect(sizes == sizes.sorted(by: >), "폰트 크기 순서가 어긋났습니다: \(sizes)")
    }

    @Test("행간이 폰트 크기보다 작지 않다")
    func lineHeightIsNotSmallerThanFontSize() {
        let tokens: [FontToken] = [
            typography.display, typography.titleLarge, typography.titleMedium,
            typography.titleSmall, typography.bodyLarge, typography.bodyMedium,
            typography.bodySmall, typography.label, typography.caption,
        ]

        for token in tokens {
            #expect(token.lineHeight >= token.size, "행간이 폰트 크기보다 작습니다: \(token)")
        }
    }

    @Test("최소 터치 영역이 HIG 권장치를 만족한다")
    func minimumHitTargetMeetsGuideline() {
        #expect(metrics.minimumHitTarget >= 44)
    }
}
