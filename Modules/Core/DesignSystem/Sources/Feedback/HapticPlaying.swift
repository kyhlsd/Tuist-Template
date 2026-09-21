//
//  HapticPlaying.swift
//  DesignSystem
//

import SwiftUI

/// 햅틱을 재생하는 쪽의 추상화.
///
/// 컴포넌트는 전역 엔진 대신 환경값 `\.hapticPlayer`로 이 프로토콜을 주입받는다.
/// 테스트에서는 재생 기록을 남기는 더블로, 햅틱을 끄는 설정에서는 `nil`로 교체한다.
public protocol HapticPlaying: AnyObject, Sendable {
    /// 즉시 재생한다.
    func play(_ haptic: AppHaptic)
    /// 곧 재생할 예정임을 시스템에 알려 지연을 줄인다.
    ///
    /// 준비 단계가 없는 구현(테스트 더블 등)은 기본 구현(아무것도 하지 않음)을 쓴다.
    func prepare(_ haptic: AppHaptic)
}

public extension HapticPlaying {
    func prepare(_: AppHaptic) {}
}

/// `@Entry`는 기본값 식을 읽을 때마다 다시 평가하므로, 생성기 캐시가 유지되도록
/// 기본 재생기 인스턴스를 하나만 만들어 둔다. 공개하지 않으며 환경값으로만 닿는다.
private let defaultHapticPlayer = SystemHapticPlayer()

public extension EnvironmentValues {
    /// 컴포넌트가 사용할 햅틱 재생기. `nil`이면 햅틱을 재생하지 않는다.
    ///
    /// 앱 설정에서 햅틱을 끄면 루트에서 `.hapticPlayer(nil)`을 주입한다.
    @Entry var hapticPlayer: (any HapticPlaying)? = defaultHapticPlayer
}

public extension (any HapticPlaying)? {
    /// 재생기와 햅틱이 모두 있을 때만 재생한다.
    ///
    /// 컴포넌트의 `haptic: nil`(이 컴포넌트는 햅틱 없음)과 환경의 `nil` 재생기(앱 전체 햅틱 끔)를
    /// 한곳에서 판단한다. 모듈 밖에서도 `@Environment(\.hapticPlayer)` 값에 그대로 호출한다.
    ///
    /// ```swift
    /// @Environment(\.hapticPlayer) private var haptics
    /// haptics.playIfEnabled(.success)
    /// ```
    func playIfEnabled(_ haptic: AppHaptic?) {
        guard case let player? = self, let haptic else { return }
        player.play(haptic)
    }

    /// 재생기와 햅틱이 모두 있을 때만 재생 준비를 요청한다.
    ///
    /// 제스처 시작 시점처럼 재생 직전에 호출하면 반응이 빨라진다.
    func prepareIfEnabled(_ haptic: AppHaptic?) {
        guard case let player? = self, let haptic else { return }
        player.prepare(haptic)
    }
}

public extension View {
    /// 하위 뷰 계층에 햅틱 재생기를 주입한다. `nil`이면 햅틱을 끈다.
    func hapticPlayer(_ player: (any HapticPlaying)?) -> some View {
        environment(\.hapticPlayer, player)
    }
}
