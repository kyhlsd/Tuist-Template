//
//  AppBottomSheet.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 시트 헤더

/// 시트 상단의 제목 영역. 닫기 버튼 위치와 여백을 통일한다.
public struct AppSheetHeader: View {
    public init(
        title: String,
        subtitle: String? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
    }

    public let title: String
    public var subtitle: String?
    public var onClose: (() -> Void)?

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.spacing.md) {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.xxs) {
                Text(title)
                    .appText(\.titleMedium, color: \.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .appText(\.bodySmall, color: \.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 표제 특성은 제목 영역에만 준다. HStack 전체에 주면 닫기 버튼까지 표제로 읽힌다.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let onClose {
                Button(action: onClose) {
                    Image(.close)
                        .appIcon(\.sm, weight: .semibold)
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(
                            width: theme.metrics.minimumHitTarget,
                            height: theme.metrics.minimumHitTarget
                        )
                        .background(theme.colors.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DesignSystemStrings.close)
            }
        }
        .padding(.bottom, theme.metrics.spacing.lg)
    }
}

// MARK: - 시트 컨테이너

/// 시트 본문에 공통 여백·배경·안전영역 처리를 적용한다.
public struct AppSheetContainer<Content: View>: View {
    public init(
        showsScroll: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.showsScroll = showsScroll
        self.content = content()
    }

    public var showsScroll: Bool = true
    @ViewBuilder public let content: Content

    @Environment(\.theme) private var theme

    public var body: some View {
        Group {
            if showsScroll {
                ScrollView {
                    body_
                }
            } else {
                body_
            }
        }
        .background(theme.colors.backgroundElevated)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.metrics.spacing.screenHorizontal)
        .padding(.top, theme.metrics.spacing.xl)
        .padding(.bottom, theme.metrics.spacing.xxl)
    }
}

// MARK: - 프레젠테이션 모디파이어

/// 시트 표시 옵션을 한곳에서 적용한다.
private struct SheetPresentationModifier: ViewModifier {
    let detents: Set<PresentationDetent>
    let showsDragIndicator: Bool

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(showsDragIndicator ? .visible : .hidden)
            .presentationCornerRadius(theme.metrics.radius.xl)
            .presentationBackground(theme.colors.backgroundElevated)
    }
}

public extension View {
    /// 디자인 시스템 규칙을 적용한 바텀시트를 표시한다.
    ///
    /// ```swift
    /// content.appSheet(isPresented: $isShowing, detents: [.medium, .large]) {
    ///     AppSheetContainer {
    ///         AppSheetHeader(title: "필터") { isShowing = false }
    ///         // 본문
    ///     }
    /// }
    /// ```
    func appSheet(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium],
        showsDragIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .modifier(
                    SheetPresentationModifier(
                        detents: detents,
                        showsDragIndicator: showsDragIndicator
                    )
                )
        }
    }

    /// 항목 기반 바텀시트. 표시할 데이터와 표시 여부를 하나로 묶어 상태 불일치를 막는다.
    func appSheet<Item: Identifiable>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.medium],
        showsDragIndicator: Bool = true,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        sheet(item: item) { value in
            content(value)
                .modifier(
                    SheetPresentationModifier(
                        detents: detents,
                        showsDragIndicator: showsDragIndicator
                    )
                )
        }
    }
}

// MARK: - 액션 시트 형태

/// 시트 하단에 고정되는 액션 영역.
///
/// 스크롤 본문과 분리해 버튼이 항상 보이도록 한다.
public struct AppSheetFooter<Content: View>: View {
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder public let content: Content

    @Environment(\.theme) private var theme

    public var body: some View {
        VStack(spacing: theme.metrics.spacing.sm) {
            content
        }
        .padding(.horizontal, theme.metrics.spacing.screenHorizontal)
        .padding(.top, theme.metrics.spacing.md)
        .padding(.bottom, theme.metrics.spacing.lg)
        .background(theme.colors.backgroundElevated)
        .overlay(alignment: .top) {
            AppDivider()
        }
    }
}
