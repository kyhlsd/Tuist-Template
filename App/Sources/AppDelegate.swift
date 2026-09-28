//
//  AppDelegate.swift
//  TuistApp
//

import os
import Push
import UIKit
import UserNotifications

/// 앱 전체 라우터의 소유자이자 APNs 등록과 알림 탭 처리 지점.
///
/// 콜드 스타트의 푸시 콜백은 뷰 트리보다 먼저 올 수 있다. AppDelegate 는
/// `didFinishLaunching` 전에 생성되므로 라우터를 여기서 만들어 뷰에 넘긴다.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let router = AppRouter(gate: AllowAllDeepLinkGate())

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 반환 전에 설정해야 콜드 스타트에서 탭한 알림도 didReceive 로 온다.
        UNUserNotificationCenter.current().delegate = self
        // 토큰은 알림 권한과 무관하게 발급된다. 토큰이 바뀔 수 있으므로 실행할 때마다 등록한다.
        // 배너·소리 권한 요청(requestAuthorization)은 제품이 정한 시점에 화면에서 한다. 첫 실행에 바로 묻지 않는다.
        application.registerForRemoteNotifications()
        return true
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = PushToken.hexString(from: deviceToken)
        // 서버에 토큰을 보내는 API 가 생기면 여기서 넘긴다. 그전까지는 로그로만 남긴다.
        Self.logger.debug("APNs 토큰을 받았습니다: \(token, privacy: .private)")
    }

    /// 시뮬레이터나 엔타이틀먼트·프로비저닝 문제로 실패할 수 있다. 푸시 없이도 앱은 동작하므로 로그만 남긴다.
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Self.logger.error("APNs 등록에 실패했습니다: \(error.localizedDescription, privacy: .public)")
    }

    private static let logger: Logger = {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("번들 ID 가 없습니다. 로그 subsystem 을 정할 수 없습니다.")
        }
        return Logger(subsystem: bundleIdentifier, category: LogCategory.push)
    }()
}

private enum LogCategory {
    static let push = "Push"
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
