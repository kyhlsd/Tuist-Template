//
//  PushPayloadTests.swift
//  PushTests
//

import Foundation
import Push
import Testing

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

    @Test("image_url 이 https URL 이면 URL 을 돌려준다")
    func imageURL_https_returnsURL() {
        let userInfo: [AnyHashable: Any] = ["image_url": "https://cdn.example.com/a.png"]

        #expect(PushPayload.imageURL(from: userInfo) == URL(string: "https://cdn.example.com/a.png"))
    }

    @Test("image_url 이 https 가 아니면 nil 이다")
    func imageURL_nonHTTPS_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["image_url": "http://cdn.example.com/a.png"]

        #expect(PushPayload.imageURL(from: userInfo) == nil)
    }

    @Test("image_url 이 파일 URL 이면 nil 이다")
    func imageURL_fileScheme_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["image_url": "file:///etc/hosts"]

        #expect(PushPayload.imageURL(from: userInfo) == nil)
    }

    @Test("image_url 키가 없으면 nil 이다")
    func imageURL_missingKey_returnsNil() {
        let userInfo: [AnyHashable: Any] = ["link": "tuistapp://home"]

        #expect(PushPayload.imageURL(from: userInfo) == nil)
    }
}
