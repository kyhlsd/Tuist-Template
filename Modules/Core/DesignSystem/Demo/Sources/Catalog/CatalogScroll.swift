//
//  CatalogScroll.swift
//  DesignSystemDemo
//
//  페이지 공통 스크롤 컨테이너.
//

import DesignSystem
import SwiftUI

struct CatalogScroll<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.xl) {
                content
            }
            .appScreenPadding()
            .padding(.vertical, theme.metrics.spacing.xl)
            .appReadableWidth()
        }
        .appScreenBackground()
    }
}
