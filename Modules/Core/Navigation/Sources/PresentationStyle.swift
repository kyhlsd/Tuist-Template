//
//  PresentationStyle.swift
//  Navigation
//

/// 모달을 띄우는 방식. 뷰모델이 `Routing.present(_:style:)` 에 넘긴다.
public nonisolated enum PresentationStyle: Hashable, Sendable {
    case sheet
    case fullScreenCover
}
