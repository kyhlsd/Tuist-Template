//
//  HapticPlayingTests.swift
//  DesignSystemTests
//

@testable import DesignSystem
import SwiftUI
import Testing

/// 재생 판단은 `playIfEnabled`/`prepareIfEnabled`와 `AsyncTaskRunner.start(_:onStart:)`에 모아 여기서 검증한다.
///
/// 검증하지 않는 경로: `.appHaptic(_:trigger:)`(`HapticFeedbackModifier`)와 `AppIconButton`은
/// 환경에서 재생기를 읽어 `playIfEnabled`를 부르기만 한다. 이 연결은 뷰를 실제로 띄워야 확인할 수 있어
/// 뷰 호스팅 없이 도는 이 테스트 타깃에서는 다루지 않는다. 재생기가 `nil`인 경우(앱 설정에서 끔)도 같은 이유로 제외한다.
@Suite("햅틱 재생기 주입")
@MainActor
struct HapticPlayingTests {
    @Test
    func hapticPlayer_기본환경_시스템재생기주입() {
        let player = EnvironmentValues().hapticPlayer

        #expect(player is SystemHapticPlayer)
    }

    /// 기본값이 읽을 때마다 새로 만들어지면 생성기 캐시와 `prepare()` 효과가 사라진다.
    @Test
    func hapticPlayer_기본값여러번읽음_같은인스턴스유지() {
        let first = EnvironmentValues().hapticPlayer
        let second = EnvironmentValues().hapticPlayer

        #expect(first === second)
    }

    @Test
    func playIfEnabled_햅틱지정_주입한재생기로재생() {
        let spy = SpyHapticPlayer()
        let player: (any HapticPlaying)? = spy

        player.playIfEnabled(.light)

        #expect(spy.played == [.light])
    }

    /// `AsyncButton(haptic: nil)`, `AppIconButton(haptic: nil)`처럼 컴포넌트에서 끈 경우.
    @Test
    func playIfEnabled_햅틱nil_재생안함() {
        let spy = SpyHapticPlayer()
        let player: (any HapticPlaying)? = spy

        player.playIfEnabled(nil)

        #expect(spy.played.isEmpty)
    }

    @Test
    func prepareIfEnabled_햅틱지정_주입한재생기로준비요청() {
        let spy = SpyHapticPlayer()
        let player: (any HapticPlaying)? = spy

        player.prepareIfEnabled(.medium)

        #expect(spy.prepared == [.medium])
    }

    @Test
    func prepareIfEnabled_햅틱nil_준비요청안함() {
        let spy = SpyHapticPlayer()
        let player: (any HapticPlaying)? = spy

        player.prepareIfEnabled(nil)

        #expect(spy.prepared.isEmpty)
    }
}

/// 재생 요청을 기록하는 테스트 더블.
@MainActor
private final class SpyHapticPlayer: HapticPlaying {
    private(set) var played: [AppHaptic] = []
    private(set) var prepared: [AppHaptic] = []

    func play(_ haptic: AppHaptic) {
        played.append(haptic)
    }

    func prepare(_ haptic: AppHaptic) {
        prepared.append(haptic)
    }
}
