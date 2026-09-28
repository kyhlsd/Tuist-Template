//
//  NotificationService.swift
//  NotificationService
//

import Push
import UserNotifications

/// 알림을 표시하기 전에 payload 의 이미지를 내려받아 첨부한다.
///
/// 시스템은 이 메서드에 약 30초를 준다. 그 안에 핸들러를 부르지 않으면 원래 알림을 그대로 보여준다.
/// 다운로드 타임아웃을 그보다 짧게 두므로(`ImageAttachmentLoader`) 제한 시간 전에 항상 핸들러를 부른다.
/// 그래서 핸들러를 저장해 두었다가 `serviceExtensionTimeWillExpire` 에서 부르는 방식은 쓰지 않는다.
final class NotificationService: UNNotificationServiceExtension {
    private let loader = ImageAttachmentLoader()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard
            let imageURL = PushPayload.imageURL(from: request.content.userInfo),
            let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }

        // SDK 가 핸들러와 알림 내용을 Sendable 로 표시하지 않아 Task 로 넘기려면 격리 검사를 끌 수밖에 없다.
        // (핸들러 이름이 completion 형태가 아니라 async 변형도 만들어지지 않는다.)
        // 안전한 이유: 이 메서드는 둘을 Task 에 넘긴 뒤 다시 건드리지 않고, Task 안에서도 한 번씩만 쓴다.
        // 핸들러는 어느 스레드에서 불러도 된다(UNNotificationServiceExtension 문서).
        nonisolated(unsafe) let deliver = contentHandler
        nonisolated(unsafe) let content = mutableContent
        Task { [loader] in
            do {
                content.attachments = try await [loader.attachment(from: imageURL)]
            } catch {
                // 이미지가 없어도 알림은 보여야 한다. 첨부 없이 원래 내용으로 보낸다.
            }
            deliver(content)
        }
    }
}
