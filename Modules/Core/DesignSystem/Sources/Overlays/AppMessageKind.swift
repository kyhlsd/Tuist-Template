//
//  AppMessageKind.swift
//  DesignSystem
//

import SwiftUI

/// 토스트 · 배너 · 인라인 알림이 공유하는 의미 구분.
///
/// 아이콘과 색 조합을 한곳에 모아, 같은 의미의 알림이 화면마다 다르게 보이는 것을 막는다.
public enum AppMessageKind: CaseIterable {
    case info
    case success
    case warning
    case error

    public var icon: AppIcon {
        switch self {
        case .info: .info
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }

    public var tint: KeyPath<ColorTokens, Color> {
        switch self {
        case .info: \.info
        case .success: \.success
        case .warning: \.warning
        case .error: \.danger
        }
    }

    public var background: KeyPath<ColorTokens, Color> {
        switch self {
        case .info: \.infoSubtle
        case .success: \.successSubtle
        case .warning: \.warningSubtle
        case .error: \.dangerSubtle
        }
    }

    /// 알림 등장 시 함께 재생할 햅틱.
    public var haptic: AppHaptic {
        switch self {
        case .info: .light
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }

    /// VoiceOver 안내 접두어.
    public var accessibilityPrefix: String {
        switch self {
        case .info: DesignSystemStrings.kindInfo
        case .success: DesignSystemStrings.kindSuccess
        case .warning: DesignSystemStrings.kindWarning
        case .error: DesignSystemStrings.kindError
        }
    }
}

/// 알림에 부착하는 단일 액션.
public struct AppMessageAction {
    public let title: String
    public let handler: () -> Void

    public init(title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}
