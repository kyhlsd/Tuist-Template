//
//  HomeDetailView.swift
//  Home
//
//  push 흐름을 보여주는 템플릿 화면. 실제 상세 화면으로 교체한다.
//  실제 화면이라면 id 로 Repository 에서 항목을 다시 읽는 뷰모델을 둔다.
//

import DesignSystem
import Domain
import SwiftUI

public struct HomeDetailView: View {
    private let itemID: Item.ID

    public init(itemID: Item.ID) {
        self.itemID = itemID
    }

    public var body: some View {
        Text(String(localized: "항목 \(itemID)", bundle: .module))
            .appText(\.bodyLarge, color: \.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appScreenBackground()
            .navigationTitle(String(localized: "상세", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
    }
}
