//
//  AppBanner.swift
//  DesignSystem
//

import SwiftUI

/// 화면 안에 자리를 차지하는 알림 영역.
///
/// 토스트와 달리 사라지지 않으므로, 오프라인 상태나 입력 검증 결과처럼
/// 조건이 유지되는 동안 계속 보여야 하는 정보에 사용한다.
public struct AppBanner: View {
    public init(
        kind: AppMessageKind,
        title: String,
        message: String? = nil,
        action: AppMessageAction? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.action = action
        self.onDismiss = onDismiss
    }

    public let kind: AppMessageKind
    public let title: String
    public var message: String?
    public var action: AppMessageAction?
    public var onDismiss: (() -> Void)?

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.spacing.md) {
            Image(kind.icon)
                .appIcon(\.sm, weight: .semibold)
                .foregroundStyle(theme.colors[keyPath: kind.tint])

            VStack(alignment: .leading, spacing: theme.metrics.spacing.xs) {
                Text(title)
                    .appText(\.label, color: \.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message {
                    Text(message)
                        .appText(\.bodySmall, color: \.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let action {
                    Button(action.title, action: action.handler)
                        .buttonStyle(.appTextButton)
                        .padding(.top, theme.metrics.spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                // 아이콘은 작아도 터치 영역은 44pt 를 확보한다. 배너 여백만큼 바깥으로 빼서
                // 배너 높이는 늘리지 않는다.
                AppIconButton(
                    icon: .close,
                    accessibilityLabel: DesignSystemStrings.dismissNotice,
                    size: \.xs,
                    tint: \.textTertiary,
                    haptic: nil,
                    action: onDismiss
                )
                .padding(-theme.metrics.spacing.md)
            }
        }
        .padding(theme.metrics.spacing.md)
        .background(
            theme.colors[keyPath: kind.background],
            in: RoundedRectangle(cornerRadius: theme.metrics.radius.md, style: .continuous)
        )
        .overlay(alignment: .leading) {
            // 색만으로 의미를 전달하지 않도록 왼쪽에 강조 막대를 둔다.
            Rectangle()
                .fill(theme.colors[keyPath: kind.tint])
                .frame(width: theme.metrics.border.focus)
                .clipShape(
                    RoundedRectangle(cornerRadius: theme.metrics.radius.md, style: .continuous)
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.accessibilityPrefix). \(title)")
    }
}

// MARK: - 상단 고정 배너

/// 상태 배너를 어디에 놓을지 정한다.
///
/// 두 배치는 필요한 메커니즘이 다르다. `safeAreaInset`은 프레임이 아니라 안전영역만
/// 줄이는데, `NavigationStack`의 내비게이션 바는 자기 프레임 최상단에 배치되므로
/// 스택 바깥에서 안전영역만 줄이면 바가 내려오지 않고 배너와 겹친다.
/// 그래서 바깥 배치는 `VStack`으로 프레임 자체를 줄인다.
public enum AppStatusBannerPlacement {
    /// 내비게이션 바 **아래**, 화면 콘텐츠 위에 표시한다.
    ///
    /// `safeAreaInset`을 사용하므로 스크롤 콘텐츠 인셋과 인디케이터 범위가 함께 조정된다.
    /// 화면 단위 상태 알림에 적합하다.
    case belowNavigationBar

    /// 내비게이션 바 **위**, 상태 바 아래에 표시한다.
    ///
    /// `NavigationStack` 바깥에 붙여야 하며, 네트워크 연결처럼 앱 전역 상태에 적합하다.
    case aboveNavigationBar
}

/// 네트워크 단절처럼 전역 상태를 알리는 얇은 상단 배너.
private struct StatusBannerModifier: ViewModifier {
    let isPresented: Bool
    let kind: AppMessageKind
    let title: String
    let placement: AppStatusBannerPlacement

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        Group {
            switch placement {
            case .belowNavigationBar:
                content
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if isPresented {
                            // 배경이 위쪽 안전영역으로 새지 않게 해 내비게이션 바 색을 보존한다.
                            banner(backgroundSafeAreaEdges: [])
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

            case .aboveNavigationBar:
                VStack(spacing: 0) {
                    if isPresented {
                        // 상태 바 뒤까지 배너 색을 이어 준다.
                        banner(backgroundSafeAreaEdges: .top)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    content
                }
            }
        }
        .animation(.app(theme.metrics.duration.normal), value: isPresented)
    }

    /// - Parameter backgroundSafeAreaEdges: 배너 배경을 어느 안전영역까지 확장할지.
    ///
    ///   `background(_ style:ignoresSafeAreaEdges:)`는 기본값이 `.all`이라,
    ///   아무것도 지정하지 않으면 배경색이 위쪽 안전영역(내비게이션 바 뒤)까지 새어 나간다.
    ///   내비게이션 바는 스크롤 최상단에서 투명하게 동작하므로 그 색이 그대로 비쳐 보인다.
    ///
    ///   - 아래 배치: `[]`를 넘겨 배경을 배너 영역 안으로 가둔다. 내비게이션 바는
    ///     원래의 스크롤 연동 동작과 색을 그대로 유지한다.
    ///   - 위 배치: `.top`을 넘겨 상태 바 뒤까지 색을 이어 준다.
    ///     본문은 안전영역 안에 남으므로 시계와 겹치지 않는다.
    private func banner(backgroundSafeAreaEdges: Edge.Set) -> some View {
        HStack(spacing: theme.metrics.spacing.sm) {
            Image(kind.icon)
                .appIcon(\.xs, weight: .semibold)
            Text(title)
                .appText(\.caption)
        }
        .foregroundStyle(theme.colors.onAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.metrics.spacing.sm)
        .background(
            theme.colors[keyPath: kind.tint],
            ignoresSafeAreaEdges: backgroundSafeAreaEdges
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.accessibilityPrefix). \(title)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

public extension View {
    /// 상단에 전역 상태 배너를 붙인다.
    ///
    /// 배치에 따라 붙이는 위치가 다르다.
    ///
    /// ```swift
    /// // 내비게이션 바 아래 — 화면 콘텐츠에 붙인다
    /// ContentView()
    ///     .appStatusBanner(isPresented: !isOnline, title: "오프라인 상태입니다")
    ///
    /// // 내비게이션 바 위 — NavigationStack 바깥에 붙인다
    /// NavigationStack { ContentView() }
    ///     .appStatusBanner(
    ///         isPresented: !isOnline,
    ///         title: "오프라인 상태입니다",
    ///         placement: .aboveNavigationBar
    ///     )
    /// ```
    ///
    /// - Note: 내비게이션 바의 투명/불투명 동작은 건드리지 않는다.
    ///   배너가 없을 때는 물론, 떠 있는 동안에도 시스템 기본 동작이 유지된다.
    func appStatusBanner(
        isPresented: Bool,
        kind: AppMessageKind = .warning,
        title: String,
        placement: AppStatusBannerPlacement = .belowNavigationBar
    ) -> some View {
        modifier(
            StatusBannerModifier(
                isPresented: isPresented,
                kind: kind,
                title: title,
                placement: placement
            )
        )
    }
}
