//
//  NavigationDemoApp.swift
//  NavigationDemo
//
//  Router 의 스택(push/pop/popToRoot)과 모달(sheet/fullScreenCover)을 조작해 보는 데모 앱.
//

import Navigation
import SwiftUI

@main
struct NavigationDemoApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            NavigationDemoRootView(router: router)
        }
    }
}
