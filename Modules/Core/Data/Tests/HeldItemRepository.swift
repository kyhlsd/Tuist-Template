//
//  HeldItemRepository.swift
//  DataTests
//

import Domain

/// 호출을 붙잡아 두었다가 테스트가 정한 순서로 끝내는 `ItemRepository`.
///
/// 겹친 요청이 끝나는 순서를 sleep 없이 맞추기 위해 쓴다.
actor HeldItemRepository: ItemRepository {
    private var held: [CheckedContinuation<[Item], Never>] = []
    private var arrivalWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func fetchItems() async throws(ItemError) -> [Item] {
        await withCheckedContinuation { continuation in
            held.append(continuation)
            resumeArrivedWaiters()
        }
    }

    /// 붙잡힌 호출이 `count` 개가 될 때까지 기다린다.
    func waitForCalls(_ count: Int) async {
        guard held.count < count else {
            return
        }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append((count, continuation))
        }
    }

    /// `index` 번째(0부터) 호출을 `items` 로 끝낸다. 한 호출은 한 번만 끝낸다.
    func finishCall(_ index: Int, with items: [Item]) {
        held[index].resume(returning: items)
    }

    private func resumeArrivedWaiters() {
        let arrived = arrivalWaiters.filter { held.count >= $0.count }
        arrivalWaiters.removeAll { held.count >= $0.count }
        for waiter in arrived {
            waiter.continuation.resume()
        }
    }
}
