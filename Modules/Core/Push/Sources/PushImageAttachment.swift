//
//  PushImageAttachment.swift
//  Push
//

import Foundation

/// 알림 이미지 첨부 판정. Notification Service Extension 이 이미지를 내려받은 뒤 이 규칙으로 받을지와 저장할 경로를 정한다.
///
/// 다운로드·파일 이동·`UNNotificationAttachment` 생성은 익스텐션이 한다. 여기는 네트워크·디스크 없이 판정만 한다.
public enum PushImageAttachment {
    /// 첨부로 받을 응답인지. 2xx 인 `HTTPURLResponse` 만 받는다.
    public static func isSuccessful(_ response: URLResponse) -> Bool {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return false }
        return Status.success.contains(status)
    }

    /// 내려받은 파일을 옮길 경로. `directory/name.<확장자>` 다.
    ///
    /// 시스템은 확장자로 첨부 형식을 판단한다. 내려받은 임시 파일에는 확장자가 없으므로 붙인다.
    /// 확장자는 `Content-Disposition` 파일 이름, 요청 URL, 응답 URL, MIME 타입 순으로 찾아 비어 있지 않은 첫 값을 쓴다.
    /// 넷 다 없으면 확장자 없이 두고, 첨부 생성이 실패한다.
    ///
    /// `suggestedFilename` 은 헤더가 있을 때만 쓴다. 헤더가 없을 때 Foundation 이 URL·MIME 타입으로 합성하는 값은
    /// OS 버전마다 다르다(iOS 26 은 "Unknown", iOS 27·macOS 는 MIME 타입 확장자를 붙인다). 그 값에 기대면
    /// 같은 응답의 확장자가 기기마다 달라진다.
    public static func fileURL(for response: URLResponse, requestURL: URL, in directory: URL, name: String) -> URL {
        let candidates = [
            contentDispositionFilename(of: response).map { ($0 as NSString).pathExtension },
            requestURL.pathExtension,
            response.url?.pathExtension,
            response.mimeType.flatMap { MIMEType.fileExtensions[$0] },
        ]
        let fileExtension = candidates.compactMap(\.self).first { !$0.isEmpty } ?? ""
        return directory
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
    }

    /// `Content-Disposition` 헤더가 있을 때 Foundation 이 해석한 파일 이름. 헤더 해석은 Foundation 에 맡긴다.
    private static func contentDispositionFilename(of response: URLResponse) -> String? {
        guard (response as? HTTPURLResponse)?.value(forHTTPHeaderField: Header.contentDisposition) != nil else {
            return nil
        }
        return response.suggestedFilename
    }

    private enum Header {
        static let contentDisposition = "Content-Disposition"
    }

    private enum Status {
        static let success = 200 ..< 300
    }

    /// 알림 첨부가 받는 이미지 형식만 둔다. `image/jpg` 는 서버가 흔히 보내는 JPEG 의 비표준 별칭이다.
    /// `HTTPURLResponse.mimeType` 은 Foundation 이 소문자로 정규화한다.
    private enum MIMEType {
        static let fileExtensions = [
            "image/jpeg": "jpg",
            "image/jpg": "jpg",
            "image/png": "png",
            "image/gif": "gif",
        ]
    }
}
