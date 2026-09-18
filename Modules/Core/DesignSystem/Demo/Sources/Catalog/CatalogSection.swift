//
//  CatalogSection.swift
//  DesignSystemDemo
//
//  페이지 안의 제목 + 카드 한 구획.
//

import DesignSystem
import SwiftUI

struct CatalogSection<Content: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.md) {
            Text(title)
                .appText(\.titleMedium, color: \.textPrimary)
            content
                .appCard()
        }
    }
}
