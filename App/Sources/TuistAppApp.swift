//
//  TuistAppApp.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

@main
struct TuistAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = AppContainer(configuration: .fromMainBundle())

    var body: some Scene {
        WindowGroup {
            RootView(container: container, router: appDelegate.router)
                .theme(.standard)
                .onOpenURL { appDelegate.router.handle($0) }
        }
    }
}
