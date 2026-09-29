//
//  DemoPageView.swift
//  NavigationDemo
//

import Navigation
import SwiftUI

/// 스택의 한 단계. 현재 깊이와 `router.path.count` 를 나란히 보여 준다.
struct DemoPageView: View {
    let router: Router
    let depth: Int

    var body: some View {
        List {
            Section("상태") {
                LabeledContent("현재 깊이", value: "\(depth)")
                LabeledContent("path.count", value: "\(router.path.count)")
            }
            Section("스택") {
                Button("다음 화면 push") {
                    router.push(DemoRoute.page(depth: depth + 1))
                }
                Button("pop") {
                    router.pop()
                }
                Button("popToRoot") {
                    router.popToRoot()
                }
            }
            Section("모달") {
                Button("sheet present") {
                    router.present(DemoRoute.modal, style: .sheet)
                }
                Button("fullScreenCover present") {
                    router.present(DemoRoute.modal, style: .fullScreenCover)
                }
            }
        }
        .navigationTitle(depth == 0 ? "루트" : "깊이 \(depth)")
    }
}
