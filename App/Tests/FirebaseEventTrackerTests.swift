//
//  FirebaseEventTrackerTests.swift
//  TuistAppTests
//

import Testing
import Tracking
@testable import TuistApp

/// 파라미터 변환만 검증한다. Analytics 호출은 Firebase 를 초기화해야 해서 테스트하지 않는다(Debug 는 초기화하지 않는다).
@Suite("FirebaseEventTracker 파라미터 변환")
struct FirebaseEventTrackerTests {
    @Test("파라미터가 없으면 nil 을 넘긴다")
    func parameters_empty_isNil() {
        #expect(FirebaseEventTracker.parameters(for: TrackingEvent(name: "e")) == nil)
    }

    @Test("문자열은 String 으로 바꾼다")
    func parameters_string_becomesString() throws {
        let parameters = try #require(FirebaseEventTracker.parameters(for: event(.string("home"))))

        #expect(parameters[Key.value] as? String == "home")
    }

    @Test("정수는 Int 로 바꾼다")
    func parameters_int_becomesInt() throws {
        let parameters = try #require(FirebaseEventTracker.parameters(for: event(.int(3))))

        #expect(parameters[Key.value] as? Int == 3)
    }

    @Test("실수는 Double 로 바꾼다")
    func parameters_double_becomesDouble() throws {
        let parameters = try #require(FirebaseEventTracker.parameters(for: event(.double(1.5))))

        #expect(parameters[Key.value] as? Double == 1.5)
    }

    private func event(_ value: TrackingValue) -> TrackingEvent {
        TrackingEvent(name: "e", parameters: [Key.value: value])
    }
}

private enum Key {
    static let value = "value"
}
