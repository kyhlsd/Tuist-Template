//
//  AppDelegate.swift
//  TuistApp
//

import UIKit

/// 앱 전체 라우터의 소유자.
///
/// 콜드 스타트의 푸시 콜백은 뷰 트리보다 먼저 올 수 있다. AppDelegate 는
/// `didFinishLaunching` 전에 생성되므로 라우터를 여기서 만들어 뷰에 넘긴다.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let router = AppRouter(gate: AllowAllDeepLinkGate())
}
