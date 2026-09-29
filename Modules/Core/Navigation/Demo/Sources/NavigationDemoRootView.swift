//
//  NavigationDemoRootView.swift
//  NavigationDemo
//

import Navigation
import SwiftUI

/// 스택과 모달을 `Router` 상태에 연결하는 루트 화면.
///
/// `Router` 는 모달을 `presented` 에 기록만 하므로, 여기서 그 값을 보고 직접 띄운다.
struct NavigationDemoRootView: View {
    @Bindable var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            DemoPageView(router: router, depth: 0)
                .navigationDestination(for: DemoRoute.self) { route in
                    switch route {
                    case let .page(depth):
                        DemoPageView(router: router, depth: depth)
                    case .modal:
                        DemoModalView(router: router)
                    }
                }
        }
        .sheet(isPresented: isPresented(.sheet)) {
            DemoModalView(router: router)
        }
        .fullScreenCover(isPresented: isPresented(.fullScreenCover)) {
            DemoModalView(router: router)
        }
    }

    /// `style` 모달이 떠 있는지를 `router.presented` 에서 읽는 바인딩.
    ///
    /// 사용자가 sheet 를 쓸어 닫으면 `Router` 가 스스로 비우지 않으므로 `set(false)` 에서 `dismiss()` 를 부른다.
    /// 다른 스타일로 교체되는 중에 들어온 `set(false)` 가 새 모달을 닫지 않도록 스타일이 같을 때만 닫는다.
    private func isPresented(_ style: PresentationStyle) -> Binding<Bool> {
        Binding(
            get: { router.presented?.style == style },
            set: { isPresented in
                guard !isPresented, router.presented?.style == style else { return }
                router.dismiss()
            }
        )
    }
}
