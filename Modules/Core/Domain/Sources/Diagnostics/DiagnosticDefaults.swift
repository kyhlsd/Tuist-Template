//
//  DiagnosticDefaults.swift
//  Domain
//

import Foundation

/// 진단 보고의 기본값. 값을 바꿀 때는 여기만 고친다.
public enum DiagnosticDefaults {
    /// 같은 fingerprint 를 다시 보내기까지의 간격. 세션당 8개인 Crashlytics 비치명 슬롯을 반복 에러가 밀어내지 않게 한다.
    public static let dedupeInterval: TimeInterval = 5 * 60
}
