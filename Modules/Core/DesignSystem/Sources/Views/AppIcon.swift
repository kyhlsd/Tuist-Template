//
//  AppIcon.swift
//  DesignSystem
//

import SwiftUI
import UIKit

// MARK: - AppIcon

/// 앱에서 사용하는 SF Symbol 목록.
///
/// 심볼 이름 오타는 빌드를 통과한 뒤 런타임에 빈 이미지로 나타나기 때문에
/// 문자열 대신 열거형으로 감싸 컴파일 타임에 차단한다.
/// 심볼 교체가 필요하면 `rawValue`만 수정하면 호출부는 그대로 유지된다.
public enum AppIcon: String, CaseIterable {
    // Navigation
    case close = "xmark"
    case back = "chevron.left"
    case forward = "chevron.right"
    case expand = "chevron.down"
    case collapse = "chevron.up"
    case more = "ellipsis"
    case home = "house"

    // Action
    case add = "plus"
    case edit = "pencil"
    case delete = "trash"
    case share = "square.and.arrow.up"
    case search = "magnifyingglass"
    case filter = "line.3.horizontal.decrease"
    case refresh = "arrow.clockwise"
    case copy = "doc.on.doc"
    /// 입력 내용 지우기.
    case clear = "xmark.circle.fill"
    /// 체크박스 안의 표시.
    case checkmark

    // Status
    case success = "checkmark.circle.fill"
    case warning = "exclamationmark.triangle.fill"
    case error = "xmark.octagon.fill"
    case info = "info.circle.fill"
    case empty = "tray"
    case offline = "wifi.slash"

    // Content
    case star
    case starFilled = "star.fill"
    case heart
    case heartFilled = "heart.fill"
    case bookmark
    case calendar
    case clock
    case person = "person.crop.circle"
    case settings = "gearshape"
    case bell
    case lock = "lock.fill"
    case photo

    /// SF Symbol 이름.
    public var systemName: String {
        rawValue
    }
}

// MARK: - Image / Label 연동

public extension Image {
    /// `Image(.settings)` 형태로 사용한다.
    init(_ icon: AppIcon) {
        self.init(systemName: icon.systemName)
    }
}

public extension Label where Title == Text, Icon == Image {
    /// 문자열 리터럴용. 자동으로 지역화 키로 처리된다.
    ///
    /// ```swift
    /// Label("설정", icon: .settings)
    /// ```
    init(_ titleKey: LocalizedStringKey, icon: AppIcon) {
        self.init(titleKey, systemImage: icon.systemName)
    }

    /// `String` 변수용. 이미 지역화된 문자열이나 서버에서 받은 값에 사용한다.
    ///
    /// `LocalizedStringKey`는 리터럴에서만 암묵 변환되므로,
    /// SwiftUI 기본 API와 동일하게 `StringProtocol` 오버로드를 함께 제공한다.
    ///
    /// ```swift
    /// Label(page.title, icon: page.icon)
    /// ```
    init(_ title: some StringProtocol, icon: AppIcon) {
        self.init(title, systemImage: icon.systemName)
    }
}

// MARK: - 크기 토큰 연동

/// 테마에서 아이콘 크기 토큰을 읽어 오는 바깥 단계.
private struct IconSizeModifier: ViewModifier {
    @Environment(\.theme) private var theme

    let keyPath: KeyPath<IconSizeTokens, CGFloat>
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.modifier(
            ScaledIconModifier(size: theme.metrics.icon[keyPath: keyPath], weight: weight)
        )
    }
}

/// Dynamic Type에 맞춰 아이콘을 확대하는 안쪽 단계.
///
/// `ScaledMetric`이 초기화 시점에 기준값을 요구하므로
/// 텍스트 스타일 모디파이어와 동일하게 2단계로 분리했다.
private struct ScaledIconModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight))
            // 심볼 폭이 달라도 레이아웃이 흔들리지 않도록 정사각 프레임을 준다.
            .frame(width: scaledSize, height: scaledSize)
    }
}

public extension View {
    /// 아이콘 크기 토큰을 적용한다.
    ///
    /// ```swift
    /// Image(.settings).appIcon(\.md)
    /// ```
    func appIcon(
        _ size: KeyPath<IconSizeTokens, CGFloat> = \.md,
        weight: Font.Weight = .medium
    ) -> some View {
        modifier(IconSizeModifier(keyPath: size, weight: weight))
    }
}

// MARK: - 검증

public extension AppIcon {
    /// 현재 OS에서 렌더링할 수 없는 심볼 목록.
    ///
    /// 테스트 타깃에서 `XCTAssertTrue(AppIcon.unavailableIcons.isEmpty)` 로 검증하면
    /// OS 버전별 심볼 누락을 CI에서 잡을 수 있다.
    static var unavailableIcons: [AppIcon] {
        allCases.filter { UIImage(systemName: $0.systemName) == nil }
    }
}
