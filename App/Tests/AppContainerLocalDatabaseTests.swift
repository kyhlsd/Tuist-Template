//
//  AppContainerLocalDatabaseTests.swift
//  TuistAppTests
//

import DiagnosticsTesting
import Persistence
import Testing
@testable import TuistApp

/// 디스크 저장소를 열지 못했을 때 메모리 저장소로 넘어가는 분기를 고정한다. 디스크는 열지 않는다.
@MainActor
@Suite("AppContainer 로컬 저장소 선택")
struct AppContainerLocalDatabaseTests {
    @Test("디스크 저장소가 열리면 메모리 저장소를 열지 않는다")
    func makeLocalDatabase_onDiskOpens_doesNotOpenInMemory() {
        var opened: [LocalDatabase.Location] = []

        _ = AppContainer.makeLocalDatabase(reporter: SpyDiagnosticReporter()) { location throws(PersistenceError) in
            opened.append(location)
            return try LocalDatabase(location: .inMemory)
        }

        #expect(opened == [.onDisk])
    }

    @Test("디스크 저장소가 열리면 보고하지 않는다")
    func makeLocalDatabase_onDiskOpens_doesNotReport() {
        let reporter = SpyDiagnosticReporter()

        _ = AppContainer.makeLocalDatabase(reporter: reporter) { _ throws(PersistenceError) in
            try LocalDatabase(location: .inMemory)
        }

        #expect(reporter.reported.isEmpty)
    }

    @Test("디스크 저장소를 열지 못하면 메모리 저장소로 연다")
    func makeLocalDatabase_onDiskFails_opensInMemory() {
        var opened: [LocalDatabase.Location] = []

        _ = AppContainer.makeLocalDatabase(reporter: SpyDiagnosticReporter()) { location throws(PersistenceError) in
            opened.append(location)
            guard location == .inMemory else {
                throw .storeUnavailable
            }
            return try LocalDatabase(location: .inMemory)
        }

        #expect(opened == [.onDisk, .inMemory])
    }

    @Test("디스크 저장소를 열지 못하면 한 번 보고한다")
    func makeLocalDatabase_onDiskFails_reportsOnce() {
        let reporter = SpyDiagnosticReporter()

        _ = AppContainer.makeLocalDatabase(reporter: reporter) { location throws(PersistenceError) in
            guard location == .inMemory else {
                throw .storeUnavailable
            }
            return try LocalDatabase(location: .inMemory)
        }

        #expect(reporter.reported.map(\.summary) == ["storeUnavailable"])
    }
}
