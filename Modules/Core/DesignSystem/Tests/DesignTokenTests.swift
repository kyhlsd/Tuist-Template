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

    /// `ratio(_:_:in:)`는 순서에 무관하다는 계약을 문서로 약속한다.
    @Test("대비율은 순서에 무관하다")
    func ratioIsSymmetric() {
        let forward = ColorContrast.ratio(theme.colors.textPrimary, theme.colors.background, in: .light)
        let backward = ColorContrast.ratio(theme.colors.background, theme.colors.textPrimary, in: .light)

        #expect(abs(forward - backward) < 0.0001)
    }

    /// AA 본문 기준(4.5:1) 바로 위에 있는 조합으로 감마 해제·가중치 회귀를 잡는다.
    @Test("대비율 계산이 WCAG 경계값과 일치한다")
    func ratioMatchesWCAGBoundary() {
        // #767676 / #FFFFFF 은 흰 배경에서 AA를 통과하는 가장 옅은 회색으로 알려진 조합이다(약 4.54:1).
        let ratio = ColorContrast.ratio(Color(rgb: 0x767676), .white, in: .light)

        #expect(abs(ratio - 4.54) < 0.01)
    }

    /// 알파를 버리면 반투명 검정도 21:1로 나와 검사를 통과해 버린다.
    @Test
    func ratio_반투명전경_배경과합성한색으로계산() throws {
        let translucent = try #require(ColorContrast.ratio(
            foreground: .black.opacity(0.5),
            background: .white,
            in: .light
        ))
        let composited = ColorContrast.ratio(Color(.sRGB, white: 0.5), .white, in: .light)

        #expect(abs(translucent - composited) < 0.01)
    }

    @Test
    func ratio_불투명전경_순서무관계산과일치() throws {
        let layered = try #require(ColorContrast.ratio(
            foreground: Color(rgb: 0x767676),
            background: .white,
            in: .light
        ))
        let plain = ColorContrast.ratio(Color(rgb: 0x767676), .white, in: .light)

        #expect(abs(layered - plain) < 0.0001)
    }

    /// 판정 API가 알파를 버리는 `ratio(_:_:in:)`로 되돌아가면 반투명 검정이 21:1로 통과해 버린다.
    @Test
    func meets_반투명전경_합성후기준미달() {
        let passes = ColorContrast.meets(
            .aa,
            foreground: .black.opacity(0.2),
            background: .white,
            in: .light
        )

        #expect(!passes)
    }

    @Test
    func meetsNonTextRequirement_반투명전경_합성후기준미달() {
        let passes = ColorContrast.meetsNonTextRequirement(
            foreground: .black.opacity(0.2),
            background: .white,
            in: .light
        )

        #expect(!passes)
    }

    @Test
    func report_반투명전경_합성한대비율보고() throws {
        let report = ColorContrast.report(
            name: "반투명",
            foreground: .black.opacity(0.5),
            background: .white,
            in: .light
        )
        let composited = ColorContrast.ratio(Color(.sRGB, white: 0.5), .white, in: .light)

        let ratio = try #require(report.ratio)
        #expect(abs(ratio - composited) < 0.01)
    }

    /// 반투명 배경은 아래에 깔리는 색에 따라 대비가 달라지므로 통과로 보고하면 안 된다.
    /// 그레이스케일 색 공간의 반투명 색도 알파가 전달돼 합성된 색으로 판정해야 한다.
    @Test
    func meets_그레이스케일반투명전경_합성후기준미달() {
        let passes = ColorContrast.meets(
            .aa,
            foreground: Color(uiColor: UIColor(white: 0, alpha: 0.2)),
            background: .white,
            in: .light
        )

        #expect(!passes)
    }

    /// 반투명 배경은 오류가 아니라 정상 입력이므로 멈추지 않고 `nil`을 돌려준다.
    @Test
    func ratio_반투명배경_nil() {
        let ratio = ColorContrast.ratio(foreground: .black, background: .white.opacity(0.5), in: .light)

        #expect(ratio == nil)
    }

    /// 판정 불가를 미달과 구분해 표시한다.
    @Test
    func verdict_반투명배경_판정불가() {
        let report = ColorContrast.report(
            name: "반투명 배경",
            foreground: .black,
            background: .white.opacity(0.5),
            in: .light
        )

        #expect(report.verdict == .indeterminate)
    }

    @Test
    func verdict_기준미달_미달() {
        let report = ColorContrast.report(name: "미달", foreground: .gray, background: .white, in: .light, threshold: 7)

        #expect(report.verdict == .fail)
    }

    @Test
    func report_반투명배경_판정불가() {
        let report = ColorContrast.report(
            name: "반투명 배경",
            foreground: .black,
            background: .white.opacity(0.5),
            in: .light
        )

        #expect(report.ratio == nil)
        #expect(!report.passes)
    }

    @Test
    func report_반투명배경_표시값판정불가() {
        let report = ColorContrast.report(
            name: "반투명 배경",
            foreground: .black,
            background: .white.opacity(0.5),
            in: .light
        )

        #expect(report.formattedRatio == "—")
        #expect(report.description.contains("판정 불가"))
    }

    @Test
    func report_불투명배경_대비율표시() {
        let report = ColorContrast.report(
            name: "경계값",
            foreground: Color(rgb: 0x767676),
            background: .white,
            in: .light
        )

        #expect(report.formattedRatio == "4.54")
    }

    @Test
    func meetsNonTextRequirement_반투명배경_미달처리() {
        let passes = ColorContrast.meetsNonTextRequirement(
            foreground: .black,
            background: .white.opacity(0.5),
            in: .light
        )

        #expect(!passes)
    }

    @Test
    func meets_반투명배경_미달처리() {
        let passes = ColorContrast.meets(
            .aa,
            foreground: .black,
            background: .white.opacity(0.5),
            in: .light
        )

        #expect(!passes)
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
