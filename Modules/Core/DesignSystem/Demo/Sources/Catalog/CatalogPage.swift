//
//  CatalogPage.swift
//  DesignSystemDemo
//
//  카탈로그 페이지 목록과 각 페이지의 화면.
//

import DesignSystem
import SwiftUI

enum CatalogPage: String, CaseIterable, Identifiable, Hashable {
    case foundation
    case controls
    case display
    case status
    case overlay
    case interaction

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .foundation: "Foundation"
        case .controls: "Controls"
        case .display: "Display"
        case .status: "Status"
        case .overlay: "Overlay"
        case .interaction: "Interaction"
        }
    }

    var icon: AppIcon {
        switch self {
        case .foundation: .photo
        case .controls: .settings
        case .display: .star
        case .status: .info
        case .overlay: .bell
        case .interaction: .heart
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .foundation: FoundationCatalog()
        case .controls: ControlsCatalog()
        case .display: DisplayCatalog()
        case .status: StatusCatalog()
        case .overlay: OverlayCatalog()
        case .interaction: InteractionCatalog()
        }
    }
}
