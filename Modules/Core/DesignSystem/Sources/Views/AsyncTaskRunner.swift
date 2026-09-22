//
//  AsyncTaskRunner.swift
//  DesignSystem
//

import Foundation
import Observation
import os

/// `AsyncButton`의 실행 상태 전이(시작 → 종료 / 취소)를 담당한다.
///
/// 작업은 **실제로 끝날 때까지** 실행 중으로 본다. 취소는 요청일 뿐이라 `action`이 취소를
/// 확인하지 않으면 계속 돌기 때문에, 취소 즉시 새 작업을 받으면 같은 요청이 두 번 나간다.
/// (예: `LazyVStack` 행이 스크롤로 사라졌다가 다시 나타나 탭되는 경우)
///
/// 뷰에서 떼어 두어 이 경합을 뷰 없이 테스트할 수 있게 한다.
///
/// - Important: `AsyncButton`은 이 타입을 `@State`로 들고 있어, 버튼이 초기화될 때마다
///   기본값 인스턴스가 새로 만들어졌다가 버려진다. `init`에 부수효과(구독, 타이머, 로그 등)를 두지 않는다.
@Observable
final class AsyncTaskRunner {
    /// 진행 중인 작업. 취소된 뒤에도 끝날 때까지 남아 있다. `nil`이면 새 작업을 받을 수 있다.
    private(set) var runningTask: Task<Void, Never>?

    #if DEBUG
        /// 취소를 요청한 시각. 취소된 작업이 오래 끝나지 않아 버튼이 잠겨 있으면 알리는 데 쓴다.
        @ObservationIgnored private var cancelledAt: ContinuousClock.Instant?
    #endif

    var isRunning: Bool {
        runningTask != nil
    }

    /// 작업을 시작한다. 이전 작업이 아직 끝나지 않았으면(취소된 경우 포함) 무시하고 `false`를 돌려준다.
    ///
    /// - Parameter onStart: 실제로 시작될 때만 한 번 호출된다. 햅틱처럼 "시작했을 때만" 일어나야 하는 일을 둔다.
    ///   거부된 탭(연타)에서는 호출되지 않는다.
    @discardableResult
    func start(_ action: @escaping () async -> Void, onStart: () -> Void = {}) -> Bool {
        guard runningTask == nil else {
            #if DEBUG
                warnIfStuckAfterCancel()
            #endif
            return false
        }

        onStart()
        runningTask = Task {
            await action()
            // 이 작업이 끝나기 전에는 새 작업이 시작될 수 없으므로, 여기서 지우는 참조는 항상 자기 자신이다.
            runningTask = nil
            #if DEBUG
                cancelledAt = nil
            #endif
        }
        return true
    }

    /// 진행 중인 작업에 취소를 요청한다.
    ///
    /// 참조는 지우지 않는다. 작업이 실제로 끝나면 스스로 비우며, 그 전까지는 새 작업을 받지 않는다.
    /// 따라서 취소를 확인하지 않고 끝나지도 않는 `action`(resume되지 않는 continuation 등)은 버튼을 계속 잠근다.
    /// 디버그 빌드에서는 이 상태로 탭이 거부되면 로그를 남긴다.
    func cancel() {
        guard let runningTask else { return }
        runningTask.cancel()
        #if DEBUG
            cancelledAt = cancelledAt ?? .now
        #endif
    }

    #if DEBUG
        /// 취소한 지 오래됐는데도 작업이 끝나지 않아 탭이 거부되면 로그를 남긴다.
        private func warnIfStuckAfterCancel() {
            guard let cancelledAt, ContinuousClock.now - cancelledAt > Diagnostics.stuckThreshold else { return }
            Diagnostics.logger.warning(
                "AsyncButton: 취소된 작업이 끝나지 않아 탭을 거부했습니다. action이 취소를 확인하는지 보세요."
            )
        }

        private enum Diagnostics {
            /// 이보다 오래 끝나지 않으면 취소를 무시하는 `action`으로 본다.
            static let stuckThreshold: Duration = .seconds(10)
            /// 앱 번들 ID를 읽지 못할 때(번들 없는 실행 환경) 쓰는 subsystem.
            static let fallbackSubsystem = "DesignSystem"
            static let category = "AsyncButton"
            /// 모든 로그의 subsystem을 앱 번들 ID로 맞춘다.
            static let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? fallbackSubsystem,
                category: category
            )
        }
    #endif
}
