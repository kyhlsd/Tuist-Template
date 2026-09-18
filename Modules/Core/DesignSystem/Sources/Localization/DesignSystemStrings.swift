//
//  DesignSystemStrings.swift
//  DesignSystem
//

import Foundation

/// DesignSystem 컴포넌트가 직접 화면에 쓰는 문구.
///
/// `Text("확인")` 처럼 리터럴을 쓰면 SwiftUI 는 **앱의 메인 번들**에서 번역을 찾는다.
/// 이 모듈의 문자열 카탈로그(Resources/Localizable.xcstrings)를 보도록 모든 문구를
/// 여기서 `bundle: .module` 로 만든다. 컴포넌트는 리터럴 대신 이 값을 쓴다.
///
/// 공개 API 의 기본 인자는 internal 심볼을 참조할 수 없으므로, 기본 문구가 있는
/// 파라미터는 `nil` 을 받아 내부에서 이 값으로 채운다.
enum DesignSystemStrings {
    // MARK: 공통 액션

    static var confirm: String {
        String(localized: "확인", bundle: .module)
    }

    static var cancel: String {
        String(localized: "취소", bundle: .module)
    }

    static var close: String {
        String(localized: "닫기", bundle: .module)
    }

    static var retry: String {
        String(localized: "다시 시도", bundle: .module)
    }

    static var delete: String {
        String(localized: "삭제", bundle: .module)
    }

    // MARK: 진행 상태

    static var inProgress: String {
        String(localized: "진행 중", bundle: .module)
    }

    static var loading: String {
        String(localized: "불러오는 중", bundle: .module)
    }

    // MARK: 상태 화면

    static var genericErrorTitle: String {
        String(localized: "문제가 발생했습니다", bundle: .module)
    }

    static var noResultsTitle: String {
        String(localized: "결과 없음", bundle: .module)
    }

    static func noResultsMessage(keyword: String) -> String {
        String(localized: "'\(keyword)'에 해당하는 항목을 찾지 못했습니다.", bundle: .module)
    }

    static var offlineTitle: String {
        String(localized: "연결할 수 없습니다", bundle: .module)
    }

    static var offlineMessage: String {
        String(localized: "네트워크 상태를 확인한 뒤 다시 시도해 주세요.", bundle: .module)
    }

    // MARK: 다이얼로그 프리셋

    static func deleteTitle(itemName: String) -> String {
        String(localized: "'\(itemName)'을(를) 삭제할까요?", bundle: .module)
    }

    static var irreversibleMessage: String {
        String(localized: "이 작업은 되돌릴 수 없습니다.", bundle: .module)
    }

    static var discardChangesTitle: String {
        String(localized: "변경 사항을 저장하지 않고 나갈까요?", bundle: .module)
    }

    static var discardChangesMessage: String {
        String(localized: "지금까지 입력한 내용이 사라집니다.", bundle: .module)
    }

    static var leave: String {
        String(localized: "나가기", bundle: .module)
    }

    static var keepEditing: String {
        String(localized: "계속 편집", bundle: .module)
    }

    // MARK: 접근성 라벨

    static var dismissNotice: String {
        String(localized: "알림 닫기", bundle: .module)
    }

    static var clearSearch: String {
        String(localized: "검색어 지우기", bundle: .module)
    }

    // MARK: 알림 종류 (VoiceOver 접두어)

    static var kindInfo: String {
        String(localized: "알림", bundle: .module)
    }

    static var kindSuccess: String {
        String(localized: "완료", bundle: .module)
    }

    static var kindWarning: String {
        String(localized: "주의", bundle: .module)
    }

    static var kindError: String {
        String(localized: "오류", bundle: .module)
    }
}
