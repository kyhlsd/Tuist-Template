//
//  PushPayload.swift
//  Push
//

import Foundation

/// 푸시 알림 payload 해석. 서버와 합의한 키를 아는 곳은 여기뿐이다.
///
/// 앱(알림 탭 → 이동)과 Notification Service Extension(표시 전 이미지 첨부)이 같은 규약을 쓰므로 모듈로 둔다.
/// 키 이름이 바뀌면 `Key` 만 고친다.
public enum PushPayload {
    /// 알림을 탭했을 때 열 링크. 앱이 딥링크와 같은 URL 로 `AppRouter.handle(_:)` 에 넘긴다.
    /// 없거나 URL 이 아니면 `nil` 이다.
    public static func link(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let value = userInfo[Key.link] as? String, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    /// 알림에 첨부할 이미지. Notification Service Extension 이 내려받아 붙인다.
    ///
    /// https 만 받는다. 알림은 서버가 보낸 값이라 다른 스킴(file, http)으로 로컬 파일이나 평문 요청을 유도하지 못하게 한다.
    /// 알림에 `mutable-content: 1` 이 있어야 익스텐션이 불린다.
    public static func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        guard
            let value = userInfo[Key.imageURL] as? String,
            let url = URL(string: value),
            url.scheme?.lowercased() == Scheme.https
        else { return nil }
        return url
    }

    private enum Key {
        static let link = "link"
        static let imageURL = "image_url"
    }

    private enum Scheme {
        static let https = "https"
    }
}
