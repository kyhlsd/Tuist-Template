//
//  AppHaptic.swift
//  DesignSystem
//

import SwiftUI
import UIKit

// MARK: - AppHaptic

/// 의미 단위로 정리한 햅틱 피드백.
///
/// `UIImpactFeedbackGenerator`를 화면마다 직접 생성하면 강도가 제각각이 되고
/// 생성기 재사용·`prepare()` 호출도 누락되기 쉬우므로 한곳으로 모은다.
public enum AppHaptic: CaseIterable {
    /// 선택 항목이 바뀔 때. 피커, 세그먼트, 칩 선택 등.
    case selection
    /// 가벼운 충돌. 토글, 작은 버튼.
    case light
    /// 보통 충돌. 주요 버튼, 시트 표시.
    case medium
    /// 강한 충돌. 드래그 스냅, 큰 상태 변화.
    case heavy
    /// 작업 성공.
    case success
    /// 주의 필요.
    case warning
    /// 작업 실패.
    case error

    /// 즉시 재생한다.
    @MainActor
    public func trigger() {
        guard AppHapticSettings.isEnabled else { return }
        HapticEngine.shared.play(self)
    }

    /// 곧 재생할 예정임을 시스템에 알려 지연을 줄인다.
    ///
    /// 제스처 시작 시점처럼 재생 직전에 호출하면 반응이 눈에 띄게 빨라진다.
    @MainActor
    public func prepare() {
        guard AppHapticSettings.isEnabled else { return }
        HapticEngine.shared.prepare(self)
    }
}

// MARK: - 사용자 설정

/// 앱 설정에서 햅틱을 끌 수 있도록 하는 전역 스위치.
///
/// 저장은 앱 레이어의 책임이므로 여기서는 값만 보관한다.
public enum AppHapticSettings {
    @MainActor public static var isEnabled: Bool = true
}

// MARK: - 엔진

@MainActor
private final class HapticEngine {
    static let shared = HapticEngine()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

    private init() {}

    func play(_ haptic: AppHaptic) {
        switch haptic {
        case .selection:
            selectionGenerator.selectionChanged()
        case .light, .medium, .heavy:
            guard let style = haptic.impactStyle else { return }
            impactGenerator(for: style).impactOccurred()
        case .success, .warning, .error:
            guard let type = haptic.notificationType else { return }
            notificationGenerator.notificationOccurred(type)
        }
    }

    func prepare(_ haptic: AppHaptic) {
        switch haptic {
        case .selection:
            selectionGenerator.prepare()
        case .light, .medium, .heavy:
            guard let style = haptic.impactStyle else { return }
            impactGenerator(for: style).prepare()
        case .success, .warning, .error:
            notificationGenerator.prepare()
        }
    }

    /// 생성기를 매번 만들면 첫 재생이 지연되므로 스타일별로 캐시한다.
    private func impactGenerator(
        for style: UIImpactFeedbackGenerator.FeedbackStyle
    ) -> UIImpactFeedbackGenerator {
        if let cached = impactGenerators[style] {
            return cached
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = generator
        return generator
    }
}

private extension AppHaptic {
    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle? {
        switch self {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        default: nil
        }
    }

    var notificationType: UINotificationFeedbackGenerator.FeedbackType? {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .error
        default: nil
        }
    }
}

// MARK: - 선언형 API

/// 값이 바뀔 때 햅틱을 재생하는 모디파이어.
private struct HapticFeedbackModifier<Value: Equatable>: ViewModifier {
    let haptic: AppHaptic
    let value: Value

    func body(content: Content) -> some View {
        content.onChange(of: value) { _, _ in
            haptic.trigger()
        }
    }
}

public extension View {
    /// 지정한 값이 바뀔 때마다 햅틱을 재생한다.
    ///
    /// ```swift
    /// Toggle("알림", isOn: $isOn)
    ///     .appHaptic(.light, trigger: isOn)
    /// ```
    func appHaptic(_ haptic: AppHaptic, trigger value: some Equatable) -> some View {
        modifier(HapticFeedbackModifier(haptic: haptic, value: value))
    }
}
