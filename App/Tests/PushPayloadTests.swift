//
//  PushPayloadTests.swift
//  TuistAppTests
//

import Foundation
import Testing
@testable import TuistApp

@Suite("PushPayload")
struct PushPayloadTests {
    @Test("link 가 URL 문자열이면 URL 을 돌려준다")
    func link_validString_returnsURL() {
        let userInfo: [AnyHashable: Any] = ["link": "tuistapp://home/items/1"]

        #expect(PushPayload.link(from: userInfo) == URL(string: "tuistapp://home/items/1"))
    }

    @Test("link 키가 없으면 nil 이다")
    func link_missingKey_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": "t"]]

        #expect(PushPayload.link(from: userInfo) == nil)
    }

    @Test("link 가 문자열이 아니면 nil 이다")
    func link_notString_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["link": 42]

        #expect(PushPayload.link(from: userInfo) == nil)
    }

    @Test("link 가 빈 문자열이면 nil 이다")
    func link_emptyString_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["link": ""]

        #expect(PushPayload.link(from: userInfo) == nil)
    }
}
