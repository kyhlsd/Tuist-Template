//
//  SystemHapticPlayer.swift
//  DesignSystem
//

import UIKit

/// UIKit 피드백 생성기로 햅틱을 재생하는 기본 구현.
///
/// `UIImpactFeedbackGenerator`를 화면마다 직접 생성하면 강도가 제각각이 되고
/// 생성기 재사용·`prepare()` 호출도 누락되기 쉬우므로 한곳으로 모은다.
final class SystemHapticPlayer: HapticPlaying {
    /// 환경 기본값은 격리 밖에서 만들어지므로 초기화는 비격리로 두고,
    /// 생성기는 처음 재생할 때(메인 액터 위에서) 만든다.
    ///
    /// 모듈 밖에서 새로 만들면 생성기 캐시가 여러 벌이 되므로 타입째 공개하지 않는다.
    /// 환경값 `\.hapticPlayer`의 기본 인스턴스 하나만 쓴다.
    nonisolated init() {}

    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

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
