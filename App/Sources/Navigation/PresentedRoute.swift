//
//  PresentedRoute.swift
//  TuistApp
//

import Foundation
import Navigation

/// 라우터가 띄운 모달 한 단계. 모달 안에 자기 내비게이션 스택(`path`)을 가진다.
///
/// `id` 는 같은 Route 를 다시 띄울 때도 새 모달로 인식되게 하려고 매번 새로 만든다.
struct PresentedRoute: Identifiable {
    let id: UUID
    let root: AppRoute
    let style: PresentationStyle
    var path: [AppRoute]

    init(root: AppRoute, style: PresentationStyle, path: [AppRoute] = [], id: UUID = UUID()) {
        self.id = id
        self.root = root
        self.style = style
        self.path = path
    }
}
