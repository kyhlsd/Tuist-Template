//
//  AppDelegate.swift
//  TuistApp
//

import UIKit
import UserNotifications

/// 앱 전체 라우터의 소유자이자 알림 탭 처리 지점.
///
/// 콜드 스타트의 푸시 콜백은 뷰 트리보다 먼저 올 수 있다. AppDelegate 는
/// `didFinishLaunching` 전에 생성되므로 라우터를 여기서 만들어 뷰에 넘긴다.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let router = AppRouter(gate: AllowAllDeepLinkGate())

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 반환 전에 설정해야 콜드 스타트에서 탭한 알림도 didReceive 로 온다.
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

/// 메인 액터에 격리된 적합성(SE-0470). 시스템이 콜백을 메인 액터에서 부르게 되어
/// 완료 처리가 메인 밖에서 불려 크래시하는 문제를 피한다.
extension AppDelegate: @MainActor UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let url = PushPayload.link(from: response.notification.request.content.userInfo) else { return }
        router.handle(url)
    }

    /// 앱을 쓰는 중에도 배너를 보여야 탭해서 이동할 수 있다.
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
