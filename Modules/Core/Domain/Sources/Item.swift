//
//  Item.swift
//  Domain
//
//  템플릿 예시 엔티티. 실제 도메인 모델로 교체한다.
//

/// 앱이 다루는 항목.
///
/// 엔티티는 저장 방식(JSON, DB)을 모른다. 변환은 Data 의 DTO 가 맡는다.
public struct Item: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
