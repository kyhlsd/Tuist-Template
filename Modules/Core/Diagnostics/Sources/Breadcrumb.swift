//
//  Breadcrumb.swift
//  Diagnostics
//

/// 에러나 크래시 직전에 무슨 일이 있었는지 보여 주는 기록 한 줄.
///
/// `message` 에는 요약값만 담는다. 헤더·바디·쿼리 같은 식별 정보는 넣지 않는다.
public struct Breadcrumb: Sendable, Equatable {
    /// 기록한 영역. 예: `network`.
    public let category: String
    public let message: String
    public let level: BreadcrumbLevel

    public init(category: String, message: String, level: BreadcrumbLevel) {
        self.category = category
        self.message = message
        self.level = level
    }
}
