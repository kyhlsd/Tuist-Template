//
//  FirebaseBootstrapTests.swift
//  TuistAppTests
//

import Testing
@testable import TuistApp

@Suite("FirebaseBootstrap 초기화 판정")
struct FirebaseBootstrapTests {
    @Test("Debug 는 설정 파일이 있어도 없어도 건너뛴다", arguments: [true, false])
    func decision_debug_skipsDebug(hasConfigFile: Bool) {
        #expect(FirebaseBootstrap.decision(isDebug: true, hasConfigFile: hasConfigFile) == .skipDebug)
    }

    @Test("Release 이고 설정 파일이 있으면 초기화한다")
    func decision_releaseWithConfigFile_configures() {
        #expect(FirebaseBootstrap.decision(isDebug: false, hasConfigFile: true) == .configure)
    }

    @Test("Release 라도 설정 파일이 없으면 건너뛴다")
    func decision_releaseWithoutConfigFile_skipsMissingConfigFile() {
        #expect(FirebaseBootstrap.decision(isDebug: false, hasConfigFile: false) == .skipMissingConfigFile)
    }
}
