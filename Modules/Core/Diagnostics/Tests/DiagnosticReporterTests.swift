//
//  DiagnosticReporterTests.swift
//  DomainTests
//

@testable import Domain
import DomainTesting
import Foundation
import os
import Testing

@Suite("DiagnosticReporter 중복 억제")
struct DiagnosticReporterTests {
    private let interval: TimeInterval = 300
    private let sink = SpyDiagnosticEventSink()
    private let fixedClock = FixedClock()

    @Test("report 는 기다리지 않고 받은 실패를 싱크로 넘긴다")
    func report_failure_reachesSink() async {
        let (sent, continuation) = AsyncStream<DiagnosticFailure>.makeStream()
        var received = sent.makeAsyncIterator()
        let reporter = DiagnosticReporter(
            sink: StreamingSink(continuation: continuation), now: fixedClock.now, dedupeInterval: interval
        )

        reporter.report(.timeout)

        // report 가 띄운 Task 가 싱크에 도달할 때까지 기다린다. 고정 대기 대신 확인 지점을 쓴다.
        #expect(await received.next() == .timeout)
    }

    @Test("첫 보고는 싱크에 그대로 전달된다")
    func handle_firstFailure_sendsToSink() async {
        let reporter = makeReporter()

        let sent = await reporter.handle(.timeout)

        #expect(sent)
        #expect(sink.sent == [.timeout])
    }

    @Test("같은 fingerprint 는 간격 안이면 억제된다")
    func handle_sameFingerprintWithinInterval_isSuppressed() async {
        let reporter = makeReporter()
        await reporter.handle(.timeout)
        fixedClock.advance(by: interval - 1)

        let sent = await reporter.handle(.timeout)

        #expect(!sent)
        #expect(sink.sent.count == 1)
    }

    @Test("같은 fingerprint 도 간격이 지나면 다시 전달된다")
    func handle_sameFingerprintAfterInterval_sendsAgain() async {
        let reporter = makeReporter()
        await reporter.handle(.timeout)
        fixedClock.advance(by: interval)

        let sent = await reporter.handle(.timeout)

        #expect(sent)
        #expect(sink.sent.count == 2)
    }

    @Test("fingerprint 가 다르면 각각 전달된다")
    func handle_differentFingerprints_sendsEach() async {
        let reporter = makeReporter()

        await reporter.handle(.timeout)
        await reporter.handle(.decoding)

        #expect(sink.sent == [.timeout, .decoding])
    }

    @Test("동시에 처리해도 같은 fingerprint 는 한 번만 전달된다")
    func handle_concurrentSameFingerprint_sendsOnce() async {
        let reporter = makeReporter()

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 10 {
                group.addTask { await reporter.handle(.timeout) }
            }
        }

        #expect(sink.sent.count == 1)
    }

    private func makeReporter() -> DiagnosticReporter {
        DiagnosticReporter(sink: sink, now: fixedClock.now, dedupeInterval: interval)
    }
}

/// 받은 실패를 스트림으로 내보내는 싱크. `report` 처럼 결과를 기다리지 않는 경로의 확인 지점이다.
///
/// 스트림과 iterator 는 테스트가 들고 있는다. `AsyncStream` 은 소비자를 하나만 지원하므로
/// 싱크가 소비 쪽을 갖지 않게 해서 여러 번 받거나 기다려도 같은 iterator 를 쓰게 한다.
private struct StreamingSink: DiagnosticEventSink {
    let continuation: AsyncStream<DiagnosticFailure>.Continuation

    func send(_ failure: DiagnosticFailure) {
        continuation.yield(failure)
    }
}

/// 테스트가 직접 움직이는 시계.
private final class FixedClock: Sendable {
    private let current = OSAllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 0))

    var now: @Sendable () -> Date {
        { self.current.withLock { $0 } }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}

private extension DiagnosticFailure {
    static let timeout = DiagnosticFailure(
        operationID: "listItems", errorType: "URLError", errorCode: -1001, summary: "URLError(-1001)", requestID: nil
    )
    static let decoding = DiagnosticFailure(
        operationID: "listItems", errorType: "DecodingError", errorCode: nil, summary: "DecodingError", requestID: "id"
    )
}
