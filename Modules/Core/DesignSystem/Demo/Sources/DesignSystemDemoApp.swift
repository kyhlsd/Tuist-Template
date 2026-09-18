//
//  DesignSystemDemoApp.swift
//  DesignSystemDemo
//
//  카탈로그만 띄우는 데모 앱 진입점.
//

import DesignSystem
import SwiftUI

@main
struct DesignSystemDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DesignSystemCatalog()
                .theme(.standard)
        }
    }
}
