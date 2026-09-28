//
//  ImageAttachmentLoader.swift
//  NotificationService
//

import Foundation
import UserNotifications

/// 이미지를 내려받아 알림 첨부로 만든다.
struct ImageAttachmentLoader {
    enum LoadError: Error {
        /// 2xx 가 아닌 응답.
        case unexpectedResponse
    }

    private let session: URLSession

    /// 익스텐션 프로세스는 알림 하나를 처리하고 끝나므로 캐시·쿠키를 남기지 않는 세션을 쓴다.
    init(session: URLSession = URLSession(configuration: .notificationAttachment)) {
        self.session = session
    }

    func attachment(from url: URL) async throws -> UNNotificationAttachment {
        let (downloadedURL, response) = try await session.download(from: url)
        guard let status = (response as? HTTPURLResponse)?.statusCode, Status.success.contains(status) else {
            throw LoadError.unexpectedResponse
        }

        // 시스템은 확장자로 첨부 형식을 판단한다. 내려받은 임시 파일에는 확장자가 없으므로 붙여서 옮긴다.
        let fileExtension = response.suggestedFilename.map { ($0 as NSString).pathExtension } ?? url.pathExtension
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try FileManager.default.moveItem(at: downloadedURL, to: fileURL)

        // 식별자를 비우면 시스템이 고유한 값을 만든다. 첨부 파일은 시스템이 자기 저장소로 옮긴다.
        return try UNNotificationAttachment(identifier: "", url: fileURL)
    }

    private enum Status {
        static let success = 200 ..< 300
    }
}

private extension URLSessionConfiguration {
    /// 시스템이 익스텐션에 주는 시간(약 30초)보다 짧게 끊어, 제한 시간 전에 첨부 없이라도 돌아오게 한다.
    static var notificationAttachment: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = Timeout.resource
        return configuration
    }

    private enum Timeout {
        static let resource: TimeInterval = 20
    }
}
