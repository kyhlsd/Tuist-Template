//
//  AppFittedSheet.swift
//  DesignSystem
//
//  콘텐츠 높이에 맞춰 시트 높이가 결정되는 형태.
//

import SwiftUI

// MARK: - 높이 측정

/// 콘텐츠(스크롤 내용물)의 높이.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 뷰포트(시트가 실제로 확보한 영역)의 높이.
private struct ViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// 자신의 높이를 지정한 키로 올린다.
    ///
    /// `background`에 넣으므로 레이아웃에는 영향을 주지 않는다.
    func measureHeight<Key: PreferenceKey>(
        _ key: Key.Type
    ) -> some View where Key.Value == CGFloat {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: key, value: proxy.size.height)
            }
        }
    }
}

// MARK: - 컨테이너

/// `AppFittedSheet` 는 제네릭이라 안에 static 저장 프로퍼티를 둘 수 없어 밖에 둔다.
private enum FittedSheetLayout {
    /// 측정 전 첫 프레임에 쓰는 높이. 짧은 목록 시트의 평균 높이.
    static let estimatedHeight: CGFloat = 200
}

/// 콘텐츠 높이에 맞춰 시트가 딱 맞게 열리는 컨테이너.
///
/// 내용이 화면보다 길어지면 시스템이 최대 높이로 잘라 주고, 그때부터 스크롤이 활성화된다.
///
/// - Important: 시트 내부에서 `GeometryReader`로 화면 높이를 읽으면 안 된다.
///   시트 안의 프록시는 화면이 아니라 시트 자신의 크기를 보고하므로,
///   그 값으로 다시 detent를 계산하면 높이가 반복 축소되어 시트가 사라진다.
public struct AppFittedSheet<Content: View>: View {
    public init(
        showsDragIndicator: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.showsDragIndicator = showsDragIndicator
        self.content = content()
    }

    public var showsDragIndicator: Bool = true
    @ViewBuilder public let content: Content

    @Environment(\.theme) private var theme

    /// 측정된 콘텐츠 높이. 초기값은 첫 프레임의 도약을 줄이기 위한 추정치다.
    @State private var contentHeight: CGFloat = FittedSheetLayout.estimatedHeight
    /// 시트가 실제로 확보한 높이. 콘텐츠가 잘렸는지 판단하는 데 쓴다.
    @State private var viewportHeight: CGFloat = 0
    /// 현재 선택된 detent. 측정값이 바뀌면 여기에 반영해야 시트가 따라 움직인다.
    @State private var selectedDetent: PresentationDetent = .height(FittedSheetLayout.estimatedHeight)

    private var isScrollable: Bool {
        viewportHeight > 0 && contentHeight > viewportHeight
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.spacing.screenHorizontal)
            .padding(.top, theme.metrics.spacing.xl)
            .padding(.bottom, theme.metrics.spacing.xxl)
            .measureHeight(ContentHeightKey.self)
        }
        .measureHeight(ViewportHeightKey.self)
        // 콘텐츠가 다 들어가면 스크롤을 막아 불필요한 바운스를 없앤다.
        .scrollDisabled(!isScrollable)
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ContentHeightKey.self) { newHeight in
            contentHeight = newHeight
        }
        .onPreferenceChange(ViewportHeightKey.self) { newHeight in
            viewportHeight = newHeight
        }
        // 요청한 높이가 화면을 넘으면 시스템이 최대 높이로 제한한다.
        .presentationDetents([.height(contentHeight)], selection: $selectedDetent)
        .onChange(of: contentHeight) { _, newHeight in
            withAnimation(.appSpring()) {
                selectedDetent = .height(newHeight)
            }
        }
        .presentationDragIndicator(showsDragIndicator ? .visible : .hidden)
        .presentationCornerRadius(theme.metrics.radius.xl)
        .presentationBackground(theme.colors.backgroundElevated)
    }
}

// MARK: - 모디파이어

public extension View {
    /// 콘텐츠 높이에 맞는 바텀시트를 표시한다.
    ///
    /// ```swift
    /// content.appFittedSheet(isPresented: $isShowing) {
    ///     AppSheetHeader(title: "정렬") { isShowing = false }
    ///     ForEach(options) { option in
    ///         AppListRow(title: option.title)
    ///     }
    /// }
    /// ```
    ///
    /// - Note: 시트 안에 텍스트 입력이 있다면 키보드가 올라올 때 높이가 부족해질 수 있다.
    ///   그 경우 `appSheet(isPresented:detents:)`로 `.large`를 함께 제공하는 편이 안전하다.
    func appFittedSheet(
        isPresented: Binding<Bool>,
        showsDragIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        sheet(isPresented: isPresented) {
            AppFittedSheet(showsDragIndicator: showsDragIndicator, content: content)
        }
    }

    /// 항목 기반 버전. 표시할 데이터와 표시 여부를 하나로 묶어 상태 불일치를 막는다.
    func appFittedSheet<Item: Identifiable>(
        item: Binding<Item?>,
        showsDragIndicator: Bool = true,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        sheet(item: item) { value in
            AppFittedSheet(showsDragIndicator: showsDragIndicator) {
                content(value)
            }
        }
    }
}
