//
//  AccessibilityModifiers.swift
//  DesignSystem
//

import SwiftUI
import UIKit

// MARK: - 접근성 상태 조회

/// 접근성 관련 시스템 상태와 안내 기능을 모아 둔다.
public enum AppAccessibility {
    /// VoiceOver 실행 여부.
    public static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// 모션 감소 설정 여부.
    ///
    /// 뷰 안에서는 `@Environment(\.accessibilityReduceMotion)`을 쓰는 편이 낫다.
    /// 이 프로퍼티는 뷰 바깥(모델·코디네이터)에서 판단이 필요할 때 사용한다.
    public static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// 화면 변화를 VoiceOver로 알린다.
    ///
    /// 토스트처럼 시각적으로만 나타나는 변화는 VoiceOver 사용자가 놓치기 쉽다.
    /// - Parameter parts: `nil`은 건너뛰고 나머지를 마침표로 이어 읽는다.
    @MainActor
    public static func announce(_ parts: String?...) {
        guard isVoiceOverRunning else { return }
        let message = parts.compactMap(\.self).joined(separator: ". ")
        guard !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// 화면 구성이 크게 바뀌었음을 알리고 포커스를 재설정한다.
    @MainActor
    public static func announceScreenChange() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}

// MARK: - 라벨 조합

private struct AccessibilityElementModifier: ViewModifier {
    let label: String
    let value: String?
    let hint: String?
    let traits: AccessibilityTraits

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

public extension View {
    /// 여러 하위 뷰를 하나의 접근성 요소로 묶는다.
    ///
    /// 카드나 목록 행처럼 제목·부제·아이콘이 섞인 구조는 개별로 읽히면
    /// 탐색 횟수만 늘어난다. 하나로 묶어 한 번에 읽게 한다.
    ///
    /// ```swift
    /// cardContent
    ///     .appAccessibilityElement(
    ///         label: "\(title), \(subtitle)",
    ///         hint: "두 번 탭하면 상세로 이동합니다",
    ///         traits: .isButton
    ///     )
    /// ```
    func appAccessibilityElement(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(
            AccessibilityElementModifier(
                label: label,
                value: value,
                hint: hint,
                traits: traits
            )
        )
    }

    /// 순수 장식 요소를 접근성 트리에서 제외한다.
    ///
    /// 구분선, 배경 도형, 텍스트와 의미가 중복되는 아이콘 등에 사용한다.
    func appDecorative() -> some View {
        accessibilityHidden(true)
    }

    /// 섹션 제목임을 알린다. VoiceOver 로터의 '표제' 탐색에 걸린다.
    func appAccessibilityHeader() -> some View {
        accessibilityAddTraits(.isHeader)
    }

    /// 여러 문자열을 하나의 라벨로 합친다. `nil`은 건너뛴다.
    ///
    /// 부제나 배지처럼 있을 수도 없을 수도 있는 값을 조합할 때 쓴다.
    func appAccessibilityLabel(_ parts: String?...) -> some View {
        accessibilityLabel(parts.compactMap(\.self).joined(separator: ", "))
    }
}

// MARK: - 동적 타입 대응

/// 접근성 확대 단계에서 가로 배치를 세로로 바꾸는 스택.
///
/// 아이콘 + 텍스트 + 액세서리가 한 줄에 놓인 구조는 확대 시 글자가 잘리기 쉽다.
/// 레이아웃 자체를 바꾸는 편이 `minimumScaleFactor`로 줄이는 것보다 읽기 좋다.
///
/// ```swift
/// AppAdaptiveStack(spacing: theme.metrics.spacing.md) {
///     Image(.calendar)
///     Text(date)
/// }
/// ```
public struct AppAdaptiveStack<Content: View>: View {
    public init(
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public let spacing: CGFloat
    @ViewBuilder public let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        // `AnyLayout`을 쓰면 축이 바뀌어도 하위 뷰 아이덴티티가 유지되어
        // 상태가 초기화되지 않고 전환도 자연스럽다.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))

        layout {
            content
        }
    }
}
