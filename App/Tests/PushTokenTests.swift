//
//  PushTokenTests.swift
//  TuistAppTests
//

import Foundation
import Testing
@testable import TuistApp

@Suite("PushToken")
struct PushTokenTests {
    @Test("바이트마다 두 자리 소문자 16진수로 이어 붙인다")
    func hexString_bytes_returnsLowercasePaddedHex() {
        let token = Data([0x00, 0x0F, 0xA0, 0xFF])

        #expect(PushToken.hexString(from: token) == "000fa0ff")
    }

    @Test("빈 토큰이면 빈 문자열이다")
    func hexString_empty_returnsEmptyString() {
        #expect(PushToken.hexString(from: Data()).isEmpty)
    }
}
