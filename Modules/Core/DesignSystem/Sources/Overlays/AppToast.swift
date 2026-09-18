//
//  AppToast.swift
//  DesignSystem
//

import Observation
import SwiftUI

// MARK: - 모델

/// 화면 위에 잠시 떠올랐다 사라지는 알림.
public struct AppToast: Identifiable {
    /// 표시 위치.
    public enum Placement {
        case top
        case bottom
    }

    public let id = UUID()
    public var kind: AppMessageKind
    public var title: String
    public var message: String?
    /// 자동 사라짐까지의 시간. `0` 이하이면 수동으로만 닫힌다.
    public var duration: TimeInterval
    public var action: AppMessageAction?

    /// 일반 토스트의 표시 시간.
    public static let standardDuration: TimeInterval = 3
    /// 오류 토스트의 표시 시간. 읽고 판단할 시간이 더 필요하다.
    public static let errorDuration: TimeInterval = 5

    /// 프리셋(`.success`, `.error` 등)으로 부족할 때 직접 구성한다.
    ///
    /// VoiceOver 가 켜져 있고 `action` 이 있으면 `duration` 과 무관하게 자동으로 닫히지 않는다.
    /// 버튼까지 이동할 시간을 보장하기 위해서다. 닫기는 VoiceOver 의 escape 제스처나 "닫기" 동작으로 한다.
    public init(
        kind: AppMessageKind,
        title: String,
        message: String? = nil,
        duration: TimeInterval = AppToast.standardDuration,
        action: AppMessageAction? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
    }
}

public extension AppToast {
    static func success(_ title: String, message: String? = nil) -> AppToast {
        AppToast(kind: .success, title: title, message: message)
    }

    static func info(_ title: String, message: String? = nil) -> AppToast {
        AppToast(kind: .info, title: title, message: message)
    }

    static func warning(_ title: String, message: String? = nil) -> AppToast {
        AppToast(kind: .warning, title: title, message: message)
    }

    /// 오류는 사용자가 읽을 시간이 더 필요하므로 기본 노출 시간을 길게 잡는다.
    static func error(
        _ title: String,
        message: String? = nil,
        retry: (() -> Void)? = nil
    ) -> AppToast {
        AppToast(
            kind: .error,
            title: title,
            message: message,
            duration: AppToast.errorDuration,
            action: retry.map { AppMessageAction(title: DesignSystemStrings.retry, handler: $0) }
        )
    }
}

// MARK: - 뷰

public struct AppToastView: View {
    public init(
        toast: AppToast,
        onDismiss: @escaping () -> Void
    ) {
        self.toast = toast
        self.onDismiss = onDismiss
    }

    public let toast: AppToast
    public let onDismiss: () -> Void

    @Environment(\.theme) private var theme

    public var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.spacing.md) {
            Image(toast.kind.icon)
                .appIcon(\.md, weight: .semibold)
                .foregroundStyle(theme.colors[keyPath: toast.kind.tint])

            VStack(alignment: .leading, spacing: theme.metrics.spacing.xxs) {
                Text(toast.title)
                    .appText(\.label, color: \.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = toast.message {
                    Text(message)
                        .appText(\.bodySmall, color: \.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let action = toast.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .buttonStyle(.appTextButton)
                .fixedSize()
            }
        }
        .padding(theme.metrics.spacing.lg)
        .frame(maxWidth: theme.metrics.formMaxWidth)
        .background(
            theme.colors.backgroundElevated,
            in: RoundedRectangle(cornerRadius: theme.metrics.radius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.radius.lg, style: .continuous)
                .strokeBorder(
                    theme.colors[keyPath: toast.kind.tint].opacity(StateOpacity.subtleTint),
                    lineWidth: theme.metrics.border.regular
                )
        }
        .appShadow(\.floating)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toast.kind.accessibilityPrefix). \(toast.title)")
    }
}

// MARK: - 프레젠터

private struct ToastPresenter: ViewModifier {
    private enum Layout {
        /// 스와이프로 닫히는 최소 이동 거리.
        static let dismissThreshold: CGFloat = 40
        /// 등장·퇴장 스프링 응답 시간. 닫힐 때를 조금 더 빠르게 해 가볍게 보이게 한다.
        static let appearResponse: Double = 0.35
        static let dismissResponse: Double = 0.3
    }

    @Binding var toast: AppToast?
    let placement: AppToast.Placement

    @Environment(\.theme) private var theme
    @State private var dragTranslation: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: placement == .top ? .top : .bottom) {
                if let toast {
                    AppToastView(toast: toast) { dismiss() }
                        .offset(y: dragTranslation)
                        .gesture(dragGesture)
                        // 스와이프는 VoiceOver 로 할 수 없으므로 닫기 동작을 따로 제공한다.
                        .accessibilityAction(.escape) { dismiss() }
                        .accessibilityAction(named: DesignSystemStrings.close) { dismiss() }
                        .padding(.horizontal, theme.metrics.spacing.screenHorizontal)
                        .padding(placement == .top ? .top : .bottom, theme.metrics.spacing.sm)
                        .transition(transition)
                }
            }
            .animation(.appSpring(response: Layout.appearResponse), value: toast?.id)
            .task(id: toast?.id) {
                await scheduleAutoDismiss()
            }
            .onChange(of: toast?.id) { _, _ in
                dragTranslation = 0
                announce()
            }
    }

    private var transition: AnyTransition {
        .move(edge: placement == .top ? .top : .bottom)
            .combined(with: .opacity)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // 표시된 방향으로만 끌리도록 제한한다.
                let translation = value.translation.height
                switch placement {
                case .top: dragTranslation = min(translation, 0)
                case .bottom: dragTranslation = max(translation, 0)
                }
            }
            .onEnded { _ in
                if abs(dragTranslation) > Layout.dismissThreshold {
                    dismiss()
                } else {
                    withAnimation(.appSpring()) { dragTranslation = 0 }
                }
            }
    }

    private func dismiss() {
        withAnimation(.appSpring(response: Layout.dismissResponse)) {
            toast = nil
        }
    }

    /// 표시 시간이 지나면 자동으로 닫는다.
    ///
    /// `task(id:)`를 쓰면 새 토스트가 올라올 때 이전 대기가 자동 취소되므로
    /// 타이머를 직접 관리할 필요가 없다.
    ///
    /// VoiceOver 사용 중이고 액션(예: 다시 시도)이 있으면 자동으로 닫지 않는다.
    /// 몇 초 안에 버튼까지 이동하기 어렵기 때문이다. (WCAG 2.2.1 시간 조절)
    private func scheduleAutoDismiss() async {
        guard let current = toast, current.duration > 0 else { return }
        guard !(current.action != nil && AppAccessibility.isVoiceOverRunning) else { return }
        // 취소되면 CancellationError 가 나는데, 바로 아래에서 취소 여부를 확인하므로 무시해도 된다.
        try? await Task.sleep(for: .seconds(current.duration))
        guard !Task.isCancelled else { return }
        dismiss()
    }

    /// VoiceOver 사용자는 화면 위 변화를 놓치기 쉬우므로 음성으로 알린다.
    private func announce() {
        guard let toast else { return }
        AppAccessibility.announce(toast.kind.accessibilityPrefix, toast.title, toast.message)
    }
}

public extension View {
    /// 토스트를 표시한다. `toast`에 값을 넣으면 등장하고, 시간이 지나면 자동으로 사라진다.
    ///
    /// ```swift
    /// @State private var toast: AppToast?
    ///
    /// content
    ///     .appToast($toast)
    ///
    /// // 표시
    /// toast = .success("저장했습니다")
    /// ```
    func appToast(
        _ toast: Binding<AppToast?>,
        placement: AppToast.Placement = .top
    ) -> some View {
        modifier(ToastPresenter(toast: toast, placement: placement))
    }
}

// MARK: - 큐

/// 토스트가 연달아 발생할 때 하나씩 순서대로 보여 준다.
///
/// 화면마다 `@State`로 관리하면 새 토스트가 이전 것을 즉시 덮어써
/// 사용자가 놓치는 경우가 생긴다. 앱 전역에 하나만 두고 주입해 사용한다.
///
/// ```swift
/// @State private var toastQueue = AppToastQueue()
///
/// RootView()
///     .appToast(queue: toastQueue)
///     .environment(toastQueue)
/// ```
@MainActor
@Observable
public final class AppToastQueue {
    public var current: AppToast?
    @ObservationIgnored private var pending: [AppToast] = []

    public init() {}

    /// 대기열에 추가한다. 표시 중인 토스트가 없으면 즉시 보여 준다.
    public func show(_ toast: AppToast) {
        guard current != nil else {
            current = toast
            return
        }
        pending.append(toast)
    }

    /// 현재 토스트를 닫고 대기 중인 다음 항목을 꺼낸다.
    public func advance() {
        current = pending.isEmpty ? nil : pending.removeFirst()
    }

    /// 대기열까지 모두 비운다.
    public func clear() {
        pending.removeAll()
        current = nil
    }
}

public extension View {
    /// 큐 기반 토스트를 표시한다.
    func appToast(
        queue: AppToastQueue,
        placement: AppToast.Placement = .top
    ) -> some View {
        appToast(
            Binding(
                get: { queue.current },
                set: { newValue in
                    if newValue == nil {
                        queue.advance()
                    } else {
                        queue.current = newValue
                    }
                }
            ),
            placement: placement
        )
    }
}
