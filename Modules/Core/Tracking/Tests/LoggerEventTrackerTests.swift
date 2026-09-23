//
//  LoggerEventTrackerTests.swift
//  TrackingTests
//

import Testing
@testable import Tracking

/// Console 에서 읽는 문구를 고정한다. 로그 출력 자체는 테스트에서 읽을 수 없으므로
/// `track` 이 보간하는 두 조각(이름, 파라미터)을 각각 확인한다.
@Suite("LoggerEventTracker 로그 문구")
struct LoggerEventTrackerTests {
    @Test("이름 앞에 접두사를 붙인다")
    func messageForName_prefixesName() {
        #expect(LoggerEventTracker.message(forName: "screen_view") == "이벤트: screen_view")
    }

    @Test("파라미터가 없으면 빈 중괄호를 남긴다")
    func messageForParameters_empty_showsEmptyBraces() {
        #expect(LoggerEventTracker.message(forParameters: [:]) == "{}")
    }

    @Test("파라미터는 키 순서로 정렬한다")
    func messageForParameters_multiple_sortsByKey() {
        let parameters: [String: TrackingValue] = ["position": .int(2), "id": .string("a1"), "list": .string("home")]

        #expect(LoggerEventTracker.message(forParameters: parameters) == "{id=a1, list=home, position=2}")
    }

    @Test("값 타입마다 그대로 표기한다", arguments: [
        (TrackingValue.string("home"), "home"),
        (TrackingValue.int(3), "3"),
        (TrackingValue.double(1.5), "1.5"),
    ])
    func messageForParameters_eachValueType_formatsValue(value: TrackingValue, expected: String) {
        #expect(LoggerEventTracker.message(forParameters: ["k": value]) == "{k=\(expected)}")
    }
}
