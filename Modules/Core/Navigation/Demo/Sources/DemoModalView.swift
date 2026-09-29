//
//  DemoModalView.swift
//  NavigationDemo
//

import Navigation
import SwiftUI

/// 라우터가 띄운 모달. 닫기와 다른 스타일로 교체(`present` 재호출)를 확인한다.
struct DemoModalView: View {
    let router: Router

    var body: some View {
        NavigationStack {
            List {
                Section("상태") {
                    LabeledContent("presented.style", value: styleDescription)
                }
                Section("동작") {
                    Button("dismiss") {
                        router.dismiss()
                    }
                    Button("sheet 로 교체") {
                        router.present(DemoRoute.modal, style: .sheet)
                    }
                    Button("fullScreenCover 로 교체") {
                        router.present(DemoRoute.modal, style: .fullScreenCover)
                    }
                }
            }
            .navigationTitle("모달")
        }
    }

    private var styleDescription: String {
        switch router.presented?.style {
        case .sheet: "sheet"
        case .fullScreenCover: "fullScreenCover"
        case nil: "없음"
        }
    }
}
