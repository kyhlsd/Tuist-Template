//
//  AppStatusViews.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 액션

/// 상태 화면 하단에 노출할 액션.
public struct AppStatusAction {
    public let title: String
    public let handler: () -> Void

    public init(title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

// MARK: - 빈 상태 / 에러 상태

/// 아이콘 + 제목 + 설명 + 액션으로 구성된 전면 상태 화면.
///
/// 빈 목록, 검색 결과 없음, 네트워크 오류 등 "본문 대신 보여줄 화면"을 하나의
/// 레이아웃으로 통일해 앱 전체의 톤을 맞춘다.
public struct AppStatusView: View {
    public init(
        icon: AppIcon,
        title: String,
        message: String? = nil,
        tint: KeyPath<ColorTokens, Color> = \.textTertiary,
        iconBackground: KeyPath<ColorTokens, Color> = \.surfaceMuted,
        primaryAction: AppStatusAction? = nil,
        secondaryAction: AppStatusAction? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.tint = tint
        self.iconBackground = iconBackground
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    private enum Layout {
        static let iconContainerSize: CGFloat = 72
        /// 넓은 화면에서 문구가 한 줄로 길게 늘어지지 않도록 하는 상한.
        static let textMaxWidth: CGFloat = 320
    }

    public let icon: AppIcon
    public let title: String
    public var message: String?
    public var tint: KeyPath<ColorTokens, Color> = \.textTertiary
    public var iconBackground: KeyPath<ColorTokens, Color> = \.surfaceMuted
    public var primaryAction: AppStatusAction?
    public var secondaryAction: AppStatusAction?

    @Environment(\.theme) private var theme

    public var body: some View {
        VStack(spacing: theme.metrics.spacing.lg) {
            Image(icon)
                .appIcon(\.xl, weight: .regular)
                .foregroundStyle(theme.colors[keyPath: tint])
                .frame(width: Layout.iconContainerSize, height: Layout.iconContainerSize)
                .background(theme.colors[keyPath: iconBackground], in: Circle())
                // 상태는 제목이 전달하므로 그림은 장식이다.
                .accessibilityHidden(true)

            VStack(spacing: theme.metrics.spacing.sm) {
                Text(title)
                    .appText(\.titleSmall, color: \.textPrimary)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .appText(\.bodyMedium, color: \.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: theme.metrics.spacing.sm) {
                    if let primaryAction {
                        Button(primaryAction.title, action: primaryAction.handler)
                            .buttonStyle(.appPrimary(size: .medium, isFullWidth: false))
                    }
                    if let secondaryAction {
                        Button(secondaryAction.title, action: secondaryAction.handler)
                            .buttonStyle(.appTextButton)
                    }
                }
                .padding(.top, theme.metrics.spacing.xs)
            }
        }
        .frame(maxWidth: Layout.textMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.metrics.spacing.xl)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 프리셋

public extension AppStatusView {
    /// 목록이 비어 있을 때.
    static func empty(
        title: String,
        message: String? = nil,
        icon: AppIcon = .empty,
        action: AppStatusAction? = nil
    ) -> AppStatusView {
        AppStatusView(
            icon: icon,
            title: title,
            message: message,
            primaryAction: action
        )
    }

    /// 검색 결과가 없을 때.
    static func noResults(
        keyword: String,
        action: AppStatusAction? = nil
    ) -> AppStatusView {
        AppStatusView(
            icon: .search,
            title: DesignSystemStrings.noResultsTitle,
            message: DesignSystemStrings.noResultsMessage(keyword: keyword),
            primaryAction: action
        )
    }

    /// 오류가 발생했을 때. 재시도 액션을 함께 노출한다.
    ///
    /// - Parameter title: `nil` 이면 "문제가 발생했습니다".
    static func error(
        title: String? = nil,
        message: String? = nil,
        retry: @escaping () -> Void
    ) -> AppStatusView {
        AppStatusView(
            icon: .warning,
            title: title ?? DesignSystemStrings.genericErrorTitle,
            message: message,
            tint: \.danger,
            iconBackground: \.dangerSubtle,
            primaryAction: AppStatusAction(title: DesignSystemStrings.retry, handler: retry)
        )
    }

    /// 네트워크 연결이 없을 때.
    static func offline(retry: @escaping () -> Void) -> AppStatusView {
        AppStatusView(
            icon: .offline,
            title: DesignSystemStrings.offlineTitle,
            message: DesignSystemStrings.offlineMessage,
            tint: \.warning,
            iconBackground: \.warningSubtle,
            primaryAction: AppStatusAction(title: DesignSystemStrings.retry, handler: retry)
        )
    }
}

// MARK: - 로딩

/// 전면 로딩 화면.
public struct AppLoadingView: View {
    public init(
        message: String? = nil
    ) {
        self.message = message
    }

    public var message: String?

    @Environment(\.theme) private var theme

    public var body: some View {
        VStack(spacing: theme.metrics.spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.colors.accent)

            if let message {
                Text(message)
                    .appText(\.bodyMedium, color: \.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.metrics.spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? DesignSystemStrings.loading)
    }
}

// MARK: - 로딩 오버레이

private struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        theme.colors.overlay.ignoresSafeArea()

                        VStack(spacing: theme.metrics.spacing.md) {
                            ProgressView()
                                .tint(theme.colors.accent)
                            if let message {
                                Text(message)
                                    .appText(\.bodySmall, color: \.textSecondary)
                            }
                        }
                        .padding(theme.metrics.spacing.xl)
                        .background(
                            theme.colors.backgroundElevated,
                            in: RoundedRectangle(
                                cornerRadius: theme.metrics.radius.lg,
                                style: .continuous
                            )
                        )
                        .appShadow(\.modal)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.app(theme.metrics.duration.normal), value: isLoading)
            // 로딩 중에는 하위 컨트롤 조작을 막는다.
            .disabled(isLoading)
    }
}

public extension View {
    /// 진행 중 조작을 차단하는 로딩 오버레이를 씌운다.
    func appLoadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - 스켈레톤

/// 콘텐츠 자리표시자용 셰이머.
///
/// 스피너보다 체감 대기 시간이 짧아 목록 로딩에 적합하다.
public struct AppSkeleton: View {
    public init(
        height: CGFloat,
        cornerRadius: KeyPath<RadiusTokens, CGFloat> = \.sm
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var height: CGFloat
    public var cornerRadius: KeyPath<RadiusTokens, CGFloat> = \.sm

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    private enum Layout {
        /// 반짝이는 띠의 밝기, 폭(트랙 대비), 이동 거리(트랙 대비), 한 번 지나가는 시간.
        static let shimmerOpacity: Double = 0.6
        static let shimmerWidthRatio: CGFloat = 0.5
        static let shimmerTravelRatio: CGFloat = 1.5
        static let shimmerDuration: Double = 1.3
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: theme.metrics.radius[keyPath: cornerRadius], style: .continuous)
            .fill(theme.colors.surfaceMuted)
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                .clear,
                                theme.colors.background.opacity(Layout.shimmerOpacity),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * Layout.shimmerWidthRatio)
                        .offset(x: phase * proxy.size.width * Layout.shimmerTravelRatio)
                    }
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: theme.metrics.radius[keyPath: cornerRadius],
                    style: .continuous
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: Layout.shimmerDuration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}
