//
//  AppPreview.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 단일 프리뷰

private struct PreviewContainerModifier: ViewModifier {
    let theme: Theme
    let addsPadding: Bool
    let addsBackground: Bool

    func body(content: Content) -> some View {
        Group {
            if addsPadding {
                content.padding(theme.metrics.spacing.lg)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(PreviewBackgroundModifier(isEnabled: addsBackground))
        .theme(theme)
    }
}

private struct PreviewBackgroundModifier: ViewModifier {
    let isEnabled: Bool

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if isEnabled {
            content.background(theme.colors.background)
        } else {
            content
        }
    }
}

public extension View {
    /// 프리뷰에 테마·여백·배경을 한 번에 적용한다.
    ///
    /// ```swift
    /// #Preview {
    ///     AppBadge(text: "완료", style: .success)
    ///         .appPreview()
    /// }
    /// ```
    func appPreview(
        theme: Theme = .standard,
        padding: Bool = true,
        background: Bool = true
    ) -> some View {
        modifier(
            PreviewContainerModifier(
                theme: theme,
                addsPadding: padding,
                addsBackground: background
            )
        )
    }
}

// MARK: - 변형 일괄 확인

/// 프리뷰에서 확인할 환경 변형.
///
/// - Note: 제네릭 타입 내부에는 static 저장 프로퍼티를 둘 수 없으므로
///   `AppPreviewVariants` 안에 중첩하지 않고 파일 스코프에 정의한다.
///   표시할 콘텐츠 타입과 무관한 값이라 바깥에 두는 편이 의미상으로도 맞다.
public struct AppPreviewVariant: Identifiable {
    public let id = UUID()
    public let name: String
    public let colorScheme: ColorScheme
    public let dynamicTypeSize: DynamicTypeSize
    public let layoutDirection: LayoutDirection

    public init(
        name: String,
        colorScheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .large,
        layoutDirection: LayoutDirection = .leftToRight
    ) {
        self.name = name
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
        self.layoutDirection = layoutDirection
    }

    /// 기본 점검 세트. 실무에서 문제가 가장 자주 드러나는 조합이다.
    public static let standard: [AppPreviewVariant] = [
        AppPreviewVariant(name: "Light"),
        AppPreviewVariant(name: "Dark", colorScheme: .dark),
        AppPreviewVariant(name: "XXL", dynamicTypeSize: .accessibility2),
        AppPreviewVariant(name: "RTL", layoutDirection: .rightToLeft),
    ]
}

/// 라이트·다크·접근성 확대를 한 화면에서 비교한다.
///
/// `#Preview` 매크로는 하나의 뷰만 반환하므로, 변형별로 매크로를 여러 개 쓰면
/// 캔버스를 오가며 확인해야 한다. 이 컨테이너는 한 번에 나란히 보여 준다.
public struct AppPreviewVariants<Content: View>: View {
    public init(
        variants: [AppPreviewVariant] = AppPreviewVariant.standard,
        theme: Theme = .standard,
        width: CGFloat = 320,
        @ViewBuilder content: () -> Content
    ) {
        self.variants = variants
        self.theme = theme
        self.width = width
        self.content = content()
    }

    public var variants: [AppPreviewVariant] = AppPreviewVariant.standard
    public var theme: Theme = .standard
    public var width: CGFloat = 320
    @ViewBuilder public let content: Content

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: theme.metrics.spacing.lg) {
                ForEach(variants) { variant in
                    VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                        Text(variant.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        content
                            .frame(width: width)
                            .appPreview(theme: theme)
                            .environment(\.colorScheme, variant.colorScheme)
                            .environment(\.dynamicTypeSize, variant.dynamicTypeSize)
                            .environment(\.layoutDirection, variant.layoutDirection)
                            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.radius.md, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.metrics.radius.md, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: theme.metrics.border.regular)
                            }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 대비 검사 프리뷰

/// 토큰 조합의 대비율을 한눈에 보여 준다.
///
/// 테스트가 실패했을 때 어떤 조합이 얼마나 모자란지 눈으로 확인하는 용도다.
public struct AppContrastInspector: View {
    public init(
        theme: Theme = .standard
    ) {
        self.theme = theme
    }

    public var theme: Theme = .standard

    private var pairs: [ColorTokenContrastPairs.Pair] {
        ColorTokenContrastPairs.all
    }

    public var body: some View {
        List {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                Section(scheme == .dark ? "Dark" : "Light") {
                    ForEach(pairs, id: \.name) { pair in
                        let report = ColorContrast.report(
                            name: pair.name,
                            foreground: theme.colors[keyPath: pair.foreground],
                            background: theme.colors[keyPath: pair.background],
                            in: scheme,
                            threshold: pair.threshold
                        )

                        HStack {
                            Text(pair.name)
                                .font(.footnote)
                            Spacer()
                            Text(String(format: "%.2f", report.ratio))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(report.passes ? Color.green : Color.red)
                            Image(report.passes ? .success : .error)
                                .foregroundStyle(report.passes ? Color.green : Color.red)
                        }
                        // 통과 여부가 색과 아이콘에만 있으므로 보고서 문장을 통째로 읽힌다.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(report.description)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Variants") {
    AppPreviewVariants {
        VStack(alignment: .leading, spacing: 12) {
            AppBanner(
                kind: .warning,
                title: "확인이 필요합니다",
                message: "설정에서 알림 권한을 허용해 주세요."
            )
            AppListRow(icon: .person, title: "계정", subtitle: "프로필과 로그인 정보")
            Button("주요 액션") {}
                .buttonStyle(.appPrimary)
        }
    }
}

#Preview("Contrast") {
    AppContrastInspector()
}
