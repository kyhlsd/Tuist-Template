//
//  AuthDemoApp.swift
//  AuthDemo
//
//  실제 Keychain 에 토큰을 저장·삭제하고 `AuthSession.states()` 전이(signedIn/signedOut/expired)를 보는 데모 앱.
//  서버 대신 `DemoRefreshServer` 가 갱신 요청에 응답한다.
//

import SwiftUI

@main
struct AuthDemoApp: App {
    @State private var model = AuthDemoModel()

    var body: some Scene {
        WindowGroup {
            AuthDemoView(model: model)
        }
    }
}
