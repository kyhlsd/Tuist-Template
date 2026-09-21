//
//  AppToastQueueTests.swift
//  DesignSystemTests
//

@testable import DesignSystem
import Foundation
import Testing

@Suite("토스트 큐")
@MainActor
struct AppToastQueueTests {
    @Test
    func show_빈큐_즉시표시() {
        let queue = AppToastQueue()
        let toast = AppToast.info("1")

        queue.show(toast)

        #expect(queue.current?.id == toast.id)
    }

    @Test
    func show_표시중_현재토스트유지() {
        let queue = AppToastQueue()
        let first = AppToast.info("1")
        let second = AppToast.info("2")

        queue.show(first)
        queue.show(second)

        #expect(queue.current?.id == first.id)
    }

    @Test
    func advance_대기열있음_다음토스트표시() {
        let queue = AppToastQueue()
        let first = AppToast.info("1")
        let second = AppToast.info("2")
        queue.show(first)
        queue.show(second)

        queue.advance()

        #expect(queue.current?.id == second.id)
    }

    @Test
    func advance_여러개대기_들어온순서대로표시() {
        let queue = AppToastQueue()
        let toasts = [AppToast.info("1"), AppToast.info("2"), AppToast.info("3")]
        toasts.forEach(queue.show)

        var shown = [queue.current?.id]
        queue.advance()
        shown.append(queue.current?.id)
        queue.advance()
        shown.append(queue.current?.id)

        let expected: [UUID?] = toasts.map(\.id)
        #expect(shown == expected)
    }

    @Test
    func advance_대기열비어있음_nil() {
        let queue = AppToastQueue()
        queue.show(.info("1"))

        queue.advance()

        #expect(queue.current == nil)
    }

    @Test
    func advance_표시중인토스트없음_nil유지() {
        let queue = AppToastQueue()

        queue.advance()

        #expect(queue.current == nil)
    }

    @Test
    func clear_대기열있음_현재토스트닫힘() {
        let queue = AppToastQueue()
        queue.show(.info("1"))
        queue.show(.info("2"))

        queue.clear()

        #expect(queue.current == nil)
    }

    @Test
    func clear_이후advance_대기열도비워짐() {
        let queue = AppToastQueue()
        queue.show(.info("1"))
        queue.show(.info("2"))
        queue.clear()

        queue.advance()

        #expect(queue.current == nil)
    }

    @Test
    func show_clear이후_새토스트즉시표시() {
        let queue = AppToastQueue()
        queue.show(.info("1"))
        queue.show(.info("2"))
        queue.clear()
        let next = AppToast.info("3")

        queue.show(next)

        #expect(queue.current?.id == next.id)
    }
}
