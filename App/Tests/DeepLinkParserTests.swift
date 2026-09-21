//
//  DeepLinkParserTests.swift
//  TuistAppTests
//

import Foundation
import Testing
@testable import TuistApp

@Suite("DeepLinkParser")
struct DeepLinkParserTests {
    private let parser = DeepLinkParser()
    private let detailLink = DeepLink(tab: .home, path: [.home(.detail(id: "1"))])

    @Test("커스텀 스킴 상세 URL 은 Home 탭의 상세 스택이 된다")
    func parse_customSchemeDetail_returnsHomeDetail() throws {
        let url = try #require(URL(string: "tuistapp://home/items/1"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("웹 URL 도 스킴과 무관하게 같은 결과가 된다")
    func parse_webURLDetail_returnsHomeDetail() throws {
        let url = try #require(URL(string: "https://example.com/home/items/1"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("탭 세그먼트만 있으면 탭 루트가 된다")
    func parse_tabOnly_returnsEmptyPath() throws {
        let url = try #require(URL(string: "tuistapp://home"))

        #expect(parser.parse(url) == DeepLink(tab: .home, path: []))
    }

    @Test("알 수 없는 탭이면 nil 이다")
    func parse_unknownTab_returnsNil() throws {
        let url = try #require(URL(string: "tuistapp://nope"))

        #expect(parser.parse(url) == nil)
    }

    @Test("탭은 맞지만 하위 경로를 해석할 수 없으면 nil 이다")
    func parse_invalidSubpath_returnsNil() throws {
        let url = try #require(URL(string: "tuistapp://home/unknown/1"))

        #expect(parser.parse(url) == nil)
    }

    @Test("쿼리와 프래그먼트는 무시한다")
    func parse_queryAndFragment_ignored() throws {
        let url = try #require(URL(string: "tuistapp://home/items/1?source=push#top"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("host 가 빈 커스텀 스킴은 경로만으로 해석한다")
    func parse_customSchemeWithoutHost_usesPath() throws {
        let url = try #require(URL(string: "tuistapp:///home/items/1"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("대문자 웹 스킴도 웹 URL 로 판정한다")
    func parse_uppercaseWebScheme_returnsHomeDetail() throws {
        let url = try #require(URL(string: "HTTPS://example.com/home/items/1"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("탭 세그먼트는 대소문자를 무시한다")
    func parse_uppercaseTabSegment_returnsHomeDetail() throws {
        let url = try #require(URL(string: "tuistapp://Home/items/1"))

        #expect(parser.parse(url) == detailLink)
    }

    @Test("탭 뒤의 세그먼트는 대소문자를 그대로 넘긴다")
    func parse_mixedCaseID_keepsCase() throws {
        let url = try #require(URL(string: "tuistapp://home/items/AbC"))

        #expect(parser.parse(url) == DeepLink(tab: .home, path: [.home(.detail(id: "AbC"))]))
    }

    @Test("세그먼트가 없으면 nil 이다")
    func parse_noSegments_returnsNil() throws {
        let url = try #require(URL(string: "https://example.com"))

        #expect(parser.parse(url) == nil)
    }
}
