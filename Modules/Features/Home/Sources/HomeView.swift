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
            // 진입과 재시도 모두 화면 수명에 묶인 이 `.task` 로 부른다. 부를지는 뷰모델이 정한다.
            .task(id: viewModel.retryRequest) {
                await viewModel.loadOnAppear()
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
            AppStatusView.error(retry: { viewModel.retry() })
        }
    }
}
