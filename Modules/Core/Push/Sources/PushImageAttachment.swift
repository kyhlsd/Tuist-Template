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
    /// 확장자는 응답이 제안한 파일 이름에서 먼저 찾고, 제안이 없으면 요청 URL 에서 찾는다.
    public static func fileURL(for response: URLResponse, requestURL: URL, in directory: URL, name: String) -> URL {
        let fileExtension = response.suggestedFilename.map { ($0 as NSString).pathExtension }
            ?? requestURL.pathExtension
        return directory
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
    }

    private enum Status {
        static let success = 200 ..< 300
    }
}
