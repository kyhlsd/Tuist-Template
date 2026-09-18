//
//  HomeView.swift
//  Home
//

import DesignSystem
import SwiftUI

public struct HomeView: View {
    @State private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle(String(localized: "홈", bundle: .module))
            // 상세에서 돌아올 때마다 다시 불러오지 않도록 처음 한 번만 부른다.
            .task {
                guard viewModel.state == .idle else { return }
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            AppLoadingView()
        case let .loaded(items) where items.isEmpty:
            AppStatusView.empty(title: String(localized: "아직 항목이 없습니다", bundle: .module))
        case let .loaded(items):
            List(items) { item in
                Button {
                    viewModel.select(item)
                } label: {
                    AppListRow(icon: .star, title: item.title)
                }
                .buttonStyle(.plain)
            }
        case .failed:
            AppStatusView.error(retry: { Task { await viewModel.load() } })
        }
    }
}
