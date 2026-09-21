//
//  AppHaptic.swift
//  DesignSystem
//

import SwiftUI

// MARK: - AppHaptic

/// 의미 단위로 정리한 햅틱 피드백.
///
/// 재생은 환경값 `\.hapticPlayer`(`HapticPlaying`)가 맡는다.
/// 뷰에서는 `@Environment(\.hapticPlayer)`로 받아 `play(_:)`를 호출한다.
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
}

// MARK: - 선언형 API

/// 값이 바뀔 때 햅틱을 재생하는 모디파이어.
private struct HapticFeedbackModifier<Value: Equatable>: ViewModifier {
    let haptic: AppHaptic
    let value: Value

    @Environment(\.hapticPlayer) private var hapticPlayer

    func body(content: Content) -> some View {
        content.onChange(of: value) { _, _ in
            hapticPlayer.playIfEnabled(haptic)
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
