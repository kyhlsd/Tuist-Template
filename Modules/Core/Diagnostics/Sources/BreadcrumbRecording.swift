//
//  BreadcrumbRecording.swift
//  Domain
//

/// breadcrumb 를 남기는 곳. 구현은 App 이 고른다(로그, Crashlytics 등).
public protocol BreadcrumbRecording: Sendable {
    /// 동기로 남긴다. 부른 순서가 기록 순서다.
    func record(_ breadcrumb: Breadcrumb)
}
