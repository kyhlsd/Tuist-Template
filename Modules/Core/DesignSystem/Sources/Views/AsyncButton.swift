//
//  AsyncButton.swift
//  DesignSystem
//

import SwiftUI

/// `async` 액션을 실행하는 버튼.
///
/// 저장·전송처럼 시간이 걸리는 작업에서 중복 탭을 막고 진행 상태를 표시한다.
/// 각 화면에서 `isLoading` 상태를 따로 만들지 않아도 되므로 상태 누락으로 인한
/// 이중 요청을 구조적으로 예방한다.
///
/// 버튼이 화면에서 사라지면(`onDisappear`, 탭 전환 포함) 진행 중인 작업에 취소를 요청한다.
/// 취소된 작업이 실제로 끝날 때까지는 다시 나타나도 진행 중으로 표시되고 탭을 받지 않는다.
///
/// - Important: 이 잠금은 **같은 뷰 identity 안에서만** 유지된다(탭 전환, `LazyVStack` 재등장).
///   화면이 새로 생성되면(내비게이션 pop 후 재진입, 조건 분기로 뷰가 다시 만들어짐 등) 실행 상태도 새로 시작되어,
///   이전 작업이 아직 돌고 있어도 다시 탭을 받는다. 중복 요청을 반드시 막아야 하거나 화면을 벗어나도
///   끝까지 완료돼야 하는 작업은 ViewModel 등 화면보다 오래 사는 쪽이 실행 상태를 소유한다.
public struct AsyncButton<Label: View>: View {
    public init(
        role: ButtonRole? = nil,
        progress: ProgressPresentation = .replacesLabel,
        progressTint: KeyPath<ColorTokens, Color> = \.onAccent,
        haptic: AppHaptic? = .light,
        action: @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.role = role
        self.progress = progress
        self.progressTint = progressTint
        self.haptic = haptic
        self.action = action
        self.label = label()
    }

    /// 진행 중 표시 방식.
    public enum ProgressPresentation {
        /// 라벨을 인디케이터로 대체한다. 버튼 크기가 유지된다.
        case replacesLabel
        /// 라벨 옆에 인디케이터를 붙인다.
        case besideLabel
        /// 인디케이터를 표시하지 않는다. 화면 전체 오버레이를 따로 쓸 때.
        case none
    }

    public var role: ButtonRole?
    public var progress: ProgressPresentation = .replacesLabel
    /// 인디케이터 색. 버튼 스타일의 전경색과 맞춰야 한다.
    /// `.appPrimary`는 기본값(`onAccent`)이 맞고, `.appSecondary`나 `.appTextButton`처럼
    /// 배경이 밝은 스타일에서는 `\.accent`나 `\.textPrimary`로 바꿔야 인디케이터가 보인다.
    public var progressTint: KeyPath<ColorTokens, Color> = \.onAccent
    /// 시작 시점에 재생할 햅틱. 필요 없으면 `nil`.
    public var haptic: AppHaptic? = .light
    public let action: () async -> Void
    @ViewBuilder public let label: Label

    @Environment(\.theme) private var theme
    @State private var runner = AsyncTaskRunner()

    private var isRunning: Bool {
        runner.isRunning
    }

    public var body: some View {
        Button(role: role, action: start) {
            content
        }
        // `disabled`를 쓰면 스타일이 비활성 색으로 바뀌어 진행 중임이 아니라
        // 사용할 수 없는 것처럼 보인다. 히트 테스트만 막아 외형을 유지한다.
        .allowsHitTesting(!isRunning)
        .accessibilityValue(isRunning ? DesignSystemStrings.inProgress : "")
        .onDisappear {
            // 화면을 벗어나면 남은 작업을 취소해 유령 업데이트를 막는다.
            runner.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch progress {
        case .replacesLabel:
            label
                .opacity(isRunning ? 0 : 1)
                .overlay {
                    if isRunning {
                        ProgressView().tint(theme.colors[keyPath: progressTint])
                    }
                }

        case .besideLabel:
            HStack(spacing: theme.metrics.spacing.sm) {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors[keyPath: progressTint])
                }
                label
            }

        case .none:
            label
        }
    }

    private func start() {
        // 탭 연타로 작업이 중복 실행되지 않도록 방어한다. 판단은 `runner` 한 곳에서 하고,
        // 햅틱은 실제로 시작될 때만 울린다(거부된 탭에서는 울리지 않는다).
        runner.start(action) {
            haptic?.trigger()
        }
    }
}

// MARK: - 편의 이니셜라이저

public extension AsyncButton where Label == Text {
    init(
        _ title: String,
        role: ButtonRole? = nil,
        progress: ProgressPresentation = .replacesLabel,
        progressTint: KeyPath<ColorTokens, Color> = \.onAccent,
        haptic: AppHaptic? = .light,
        action: @escaping () async -> Void
    ) {
        self.role = role
        self.progress = progress
        self.progressTint = progressTint
        self.haptic = haptic
        self.action = action
        label = Text(title)
    }
}

public extension AsyncButton where Label == SwiftUI.Label<Text, Image> {
    init(
        _ title: String,
        icon: AppIcon,
        role: ButtonRole? = nil,
        progress: ProgressPresentation = .replacesLabel,
        progressTint: KeyPath<ColorTokens, Color> = \.onAccent,
        haptic: AppHaptic? = .light,
        action: @escaping () async -> Void
    ) {
        self.role = role
        self.progress = progress
        self.progressTint = progressTint
        self.haptic = haptic
        self.action = action
        label = SwiftUI.Label(title, icon: icon)
    }
}
