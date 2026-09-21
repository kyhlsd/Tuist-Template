//
//  PushPayload.swift
//  TuistApp
//

import Foundation

/// 푸시 알림 payload 해석.
///
/// 이동할 곳은 딥링크와 같은 URL 문자열로 받아 `AppRouter.handle(_:)` 에 넘긴다.
/// 키 이름은 서버와 합의한 값이다. 바뀌면 `Key` 만 고친다.
enum PushPayload {
    /// 알림을 탭했을 때 열 링크. 없거나 URL 이 아니면 `nil` 이다.
    static func link(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let value = userInfo[Key.link] as? String, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private enum Key {
        static let link = "link"
    }
}
