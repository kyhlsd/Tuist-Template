//
//  PushImageAttachmentTests.swift
//  PushTests
//

import Foundation
import Push
import Testing

@Suite("PushImageAttachment")
struct PushImageAttachmentTests {
    private let directory = URL(fileURLWithPath: "/tmp/attachments", isDirectory: true)

    @Test("2xx 응답이면 받는다", arguments: [200, 299])
    func isSuccessful_status2xx_returnsTrue(status: Int) throws {
        #expect(try PushImageAttachment.isSuccessful(response(status: status)))
    }

    @Test("2xx 가 아닌 응답(리다이렉트·클라이언트 에러)은 받지 않는다", arguments: [199, 300, 404])
    func isSuccessful_statusOutside2xx_returnsFalse(status: Int) throws {
        #expect(try !PushImageAttachment.isSuccessful(response(status: status)))
    }

    @Test("HTTPURLResponse 가 아니면 받지 않는다")
    func isSuccessful_nonHTTPResponse_returnsFalse() throws {
        let response = try URLResponse(
            url: imageURL("cat.png"),
            mimeType: "image/png",
            expectedContentLength: 0,
            textEncodingName: nil
        )

        #expect(!PushImageAttachment.isSuccessful(response))
    }

    @Test("Content-Disposition 파일 이름이 있으면 URL 확장자보다 그 확장자를 쓴다")
    func fileURL_contentDispositionFilename_usesItsExtension() throws {
        let url = try imageURL("cat.png")
        let response = try response(url: url, headers: ["Content-Disposition": "attachment; filename=\"dog.jpg\""])

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL.pathExtension == "jpg")
    }

    /// 헤더가 없으면 `suggestedFilename` 이 응답 URL 의 마지막 경로라 요청 URL 까지 가지 않는다.
    @Test("헤더가 없으면 응답 URL 에서 제안한 파일 이름의 확장자를 쓴다")
    func fileURL_noHeader_usesSuggestedFilenameExtension() throws {
        let url = try imageURL("cat.gif")
        let response = try response(url: url)

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL.pathExtension == "gif")
    }

    @Test("결과는 directory/name.확장자 다")
    func fileURL_placesNameInDirectory() throws {
        let url = try imageURL("cat.png")
        let response = try response(url: url)

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL == directory.appendingPathComponent("id.png"))
    }

    @Test(
        "헤더도 URL 확장자도 없으면 MIME 타입으로 확장자를 정한다",
        arguments: [("image/jpeg", "jpg"), ("image/jpg", "jpg"), ("image/png", "png"), ("image/gif", "gif")]
    )
    func fileURL_noExtensionWithImageMIMEType_usesMappedExtension(mimeType: String, fileExtension: String) throws {
        let url = try imageURL("cat")
        let response = try response(url: url, headers: ["Content-Type": mimeType])

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL == directory.appendingPathComponent("id.\(fileExtension)"))
    }

    @Test("Content-Type 이 대문자여도 MIME 타입 확장자를 찾는다(Foundation 이 소문자로 정규화한다)")
    func fileURL_uppercaseMIMEType_usesMappedExtension() throws {
        let url = try imageURL("cat")
        let response = try response(url: url, headers: ["Content-Type": "IMAGE/PNG"])

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL.pathExtension == "png")
    }

    /// 확장자 있는 요청 URL 이 확장자 없는 URL(예: 서명 URL)로 리다이렉트되면 응답 URL 은 최종 URL 이다.
    /// 제안 파일 이름은 "Unknown" 이라 확장자가 비고, 요청 URL 확장자가 MIME 타입보다 먼저 쓰인다.
    @Test("응답 URL 에 확장자가 없으면(리다이렉트) 요청 URL 확장자를 MIME 타입보다 먼저 쓴다")
    func fileURL_redirectedToExtensionlessURL_usesRequestURLExtension() throws {
        let requestURL = try imageURL("cat.png")
        let response = try response(url: imageURL("signed-abc"), headers: ["Content-Type": "image/jpeg"])

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: requestURL, in: directory, name: "id")

        #expect(fileURL.pathExtension == "png")
    }

    @Test("표에 없는 MIME 타입이면 확장자 없이 이름만 남는다")
    func fileURL_unmappedMIMEType_returnsNameWithoutExtension() throws {
        let url = try imageURL("cat")
        let response = try response(url: url, headers: ["Content-Type": "application/octet-stream"])

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL == directory.appendingPathComponent("id"))
    }

    /// 헤더도 URL 확장자도 없으면 `suggestedFilename` 이 "Unknown" 이라 확장자가 비고, 이름만 남는다.
    /// 시스템이 형식을 판단하지 못해 첨부가 실패하는 경우다.
    @Test("헤더도 URL 확장자도 없으면 확장자 없이 이름만 남는다")
    func fileURL_noExtensionAnywhere_returnsNameWithoutExtension() throws {
        let url = try imageURL("cat")
        let response = try response(url: url)

        let fileURL = PushImageAttachment.fileURL(for: response, requestURL: url, in: directory, name: "id")

        #expect(fileURL == directory.appendingPathComponent("id"))
        #expect(fileURL.pathExtension.isEmpty)
    }

    private func imageURL(_ lastPathComponent: String) throws -> URL {
        try #require(URL(string: "https://example.com/images/\(lastPathComponent)"))
    }

    private func response(url: URL? = nil, status: Int = 200, headers: [String: String]? = nil) throws -> HTTPURLResponse {
        let url = try url ?? imageURL("cat.png")
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers))
    }
}
