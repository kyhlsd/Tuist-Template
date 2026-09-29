//
//  DemoStoreOpenFailure.swift
//  PersistenceDemo
//

import Persistence

/// `.onDisk` 와 폴백 `.inMemory` 가 모두 열리지 않았을 때의 두 에러. 실패 화면이 둘 다 보여 준다.
struct DemoStoreOpenFailure: Error {
    let onDisk: PersistenceError
    let inMemory: PersistenceError
}
