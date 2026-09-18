//
//  TuistAppApp.swift
//  TuistApp
//

import DesignSystem
import SwiftUI

@main
struct TuistAppApp: App {
    private let container = AppContainer(configuration: .fromMainBundle())

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .theme(.standard)
        }
    }
}
