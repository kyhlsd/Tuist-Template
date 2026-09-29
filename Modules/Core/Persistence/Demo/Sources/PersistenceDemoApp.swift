//
//  PersistenceDemoApp.swift
//  PersistenceDemo
//
//  실제 디스크(SwiftData `.onDisk`, `UserDefaults`)에 쓴 값이 재실행 뒤에도 남는지 보는 데모 앱.
//  디스크 저장소를 열지 못하면 앱 조립과 같이 `.inMemory` 로 폴백하고 그 사실을 화면에 표시한다.
//

import Persistence
import SwiftUI

@main
struct PersistenceDemoApp: App {
    @State private var model = Self.makeModel()

    var body: some Scene {
        WindowGroup {
            switch model {
            case let .success(model):
                PersistenceDemoView(model: model)
            case let .failure(failure):
                ContentUnavailableView(
                    "저장소를 열 수 없습니다",
                    systemImage: "externaldrive.badge.xmark",
                    description: Text(
                        "onDisk: \(String(describing: failure.onDisk))\ninMemory: \(String(describing: failure.inMemory))"
                    )
                )
            }
        }
    }

    /// 저장소를 열고 모델을 조립한다. 실행 횟수는 여기서 한 번만 올린다.
    ///
    /// `.onDisk` 에러는 폴백한 이유이므로 버리지 않고 모델(폴백 성공)이나 실패 화면(폴백 실패)에 넘긴다.
    private static func makeModel() -> Result<PersistenceDemoModel, DemoStoreOpenFailure> {
        let database: LocalDatabase
        let onDiskError: PersistenceError?
        do {
            database = try LocalDatabase(location: .onDisk)
            onDiskError = nil
        } catch {
            onDiskError = error
            do {
                database = try LocalDatabase(location: .inMemory)
            } catch let inMemoryError {
                return .failure(DemoStoreOpenFailure(onDisk: error, inMemory: inMemoryError))
            }
        }
        let model = PersistenceDemoModel(
            cache: SwiftDataItemCache(database: database),
            settings: UserDefaultsKeyValueStore(),
            onDiskError: onDiskError
        )
        model.incrementLaunchCount()
        return .success(model)
    }
}
