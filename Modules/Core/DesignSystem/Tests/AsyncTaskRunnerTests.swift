//
//  AsyncTaskRunnerTests.swift
//  DesignSystemTests
//

@testable import DesignSystem
import Testing

@Suite("AsyncButton 실행 상태")
@MainActor
struct AsyncTaskRunnerTests {
    @Test
    func start_실행중_중복시작무시() {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        runner.start { await gate.wait() }

        let startedAgain = runner.start {}

        #expect(!startedAgain)
        runner.cancel()
    }

    /// `AsyncButton`은 햅틱을 `onStart`에서 재생한다.
    @Test
    func start_시작됨_onStart한번호출() {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        var startCount = 0

        runner.start {
            await gate.wait()
        } onStart: {
            startCount += 1
        }

        #expect(startCount == 1)
        runner.cancel()
    }

    /// 연타로 거부된 탭에서는 햅틱이 울리면 안 된다.
    @Test
    func start_실행중재탭_onStart호출안함() {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        var startCount = 0
        runner.start {
            await gate.wait()
        } onStart: {
            startCount += 1
        }

        runner.start {} onStart: {
            startCount += 1
        }

        #expect(startCount == 1)
        runner.cancel()
    }

    @Test
    func start_작업완료_다시시작가능() async {
        let runner = AsyncTaskRunner()
        runner.start {}

        await runner.runningTask?.value
        let startedAgain = runner.start {}

        #expect(startedAgain)
    }

    /// 사라짐(취소) → 다시 나타나 재탭 순서에서, 취소를 무시하고 도는 이전 작업이 끝나기 전에는
    /// 같은 요청이 한 번 더 나가면 안 된다.
    @Test
    func start_취소된이전작업이아직실행중_재시작막음() {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        runner.start { await gate.wait() }
        runner.cancel()

        // 테스트가 메인 액터를 양보하지 않았으므로 이전 작업은 아직 끝나지 않았다.
        let startedAgain = runner.start {}

        #expect(!startedAgain)
    }

    @Test
    func cancel_취소된작업이실제로끝날때까지_실행중유지() {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        runner.start { await gate.wait() }

        runner.cancel()

        #expect(runner.isRunning)
    }

    @Test
    func start_취소된작업종료후_다시시작가능() async {
        let runner = AsyncTaskRunner()
        let gate = Gate()
        runner.start { await gate.wait() }
        let cancelledTask = runner.runningTask
        runner.cancel()

        await cancelledTask?.value
        let startedAgain = runner.start {}

        #expect(startedAgain)
    }
}

/// 작업이 취소될 때까지 붙잡아 두는 확인 지점. 고정 대기 없이 "실행 중" 상태를 만든다.
private struct Gate {
    private let stream: AsyncStream<Void>
    /// 이어짐이 해제되면 스트림이 끝나 대기가 풀리므로, 게이트가 살아 있는 동안 붙잡아 둔다.
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream<Void>.makeStream()
    }

    /// 취소되면 스트림 순회가 끝나며 반환한다.
    func wait() async {
        for await _ in stream {
            return
        }
    }
}
