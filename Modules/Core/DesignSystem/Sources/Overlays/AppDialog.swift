//
//  AppDialog.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 모델

/// 확인 다이얼로그 구성.
///
/// `alert`와 `confirmationDialog`는 시스템이 직접 그리므로 외형을 바꿀 수 없다.
/// 대신 문구 구성과 버튼 순서를 한 타입으로 묶어 앱 전체의 어조를 통일한다.
public struct AppDialog: Identifiable {
    public let id = UUID()
    public var title: String
    public var message: String?
    public var confirmTitle: String
    public var cancelTitle: String
    /// 되돌릴 수 없는 작업이면 확인 버튼을 빨간색으로 표시한다.
    public var isDestructive: Bool
    public var onConfirm: () -> Void

    /// 프리셋(`.delete`, `.discardChanges`)으로 부족할 때 직접 구성한다.
    ///
    /// - Parameters:
    ///   - confirmTitle: `nil` 이면 "확인".
    ///   - cancelTitle: `nil` 이면 "취소".
    public init(
        title: String,
        message: String? = nil,
        confirmTitle: String? = nil,
        cancelTitle: String? = nil,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle ?? DesignSystemStrings.confirm
        self.cancelTitle = cancelTitle ?? DesignSystemStrings.cancel
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
    }
}

public extension AppDialog {
    /// 삭제 확인. "이 작업은 되돌릴 수 없습니다." 안내가 함께 표시된다.
    /// 대상 이름을 넣으면 무엇을 지우는지 명확해진다.
    static func delete(
        itemName: String,
        onConfirm: @escaping () -> Void
    ) -> AppDialog {
        delete(itemName: itemName, message: DesignSystemStrings.irreversibleMessage, onConfirm: onConfirm)
    }

    /// 삭제 확인. 안내 문구를 바꾸거나(`nil` 이면 생략) 할 때 쓴다.
    static func delete(
        itemName: String,
        message: String?,
        onConfirm: @escaping () -> Void
    ) -> AppDialog {
        AppDialog(
            title: DesignSystemStrings.deleteTitle(itemName: itemName),
            message: message,
            confirmTitle: DesignSystemStrings.delete,
            isDestructive: true,
            onConfirm: onConfirm
        )
    }

    /// 편집 내용을 버리고 나갈 때.
    static func discardChanges(onConfirm: @escaping () -> Void) -> AppDialog {
        AppDialog(
            title: DesignSystemStrings.discardChangesTitle,
            message: DesignSystemStrings.discardChangesMessage,
            confirmTitle: DesignSystemStrings.leave,
            cancelTitle: DesignSystemStrings.keepEditing,
            isDestructive: true,
            onConfirm: onConfirm
        )
    }
}

// MARK: - 표시 방식

/// 확인 다이얼로그를 어떤 형태로 띄울지.
public enum AppDialogPresentation {
    /// `confirmationDialog`. iPhone에서는 하단 시트, iPad·Mac에서는 팝오버로 표시된다.
    ///
    /// 팝오버는 이 모디파이어가 붙은 뷰에 앵커되므로, **액션을 실행하는 버튼 가까이**
    /// 붙여야 한다. 화면 루트에 붙이면 버튼과 동떨어진 위치에 뜬다.
    case confirmation

    /// `alert`. 기기와 무관하게 화면 중앙에 표시되어 앵커 문제가 없다.
    ///
    /// 여러 버튼이 하나의 다이얼로그 상태를 공유하거나, 모디파이어를 화면 루트에
    /// 모아 두는 구조라면 이쪽이 안전하다.
    case alert
}

// MARK: - 모디파이어

private struct DialogModifier: ViewModifier {
    @Binding var dialog: AppDialog?
    let presentation: AppDialogPresentation

    func body(content: Content) -> some View {
        switch presentation {
        case .confirmation:
            content.confirmationDialog(
                dialog?.title ?? "",
                isPresented: isPresented,
                titleVisibility: .visible,
                presenting: dialog
            ) { current in
                actions(for: current)
            } message: { current in
                message(for: current)
            }

        case .alert:
            content.alert(
                dialog?.title ?? "",
                isPresented: isPresented,
                presenting: dialog
            ) { current in
                actions(for: current)
            } message: { current in
                message(for: current)
            }
        }
    }

    @ViewBuilder
    private func actions(for current: AppDialog) -> some View {
        Button(
            current.confirmTitle,
            role: current.isDestructive ? .destructive : nil
        ) {
            current.onConfirm()
        }

        Button(current.cancelTitle, role: .cancel) {}
    }

    @ViewBuilder
    private func message(for current: AppDialog) -> some View {
        if let message = current.message {
            Text(message)
        }
    }

    /// 표시 여부와 데이터가 어긋나지 않도록 옵셔널에서 파생시킨다.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { dialog != nil },
            set: { newValue in
                if !newValue {
                    dialog = nil
                }
            }
        )
    }
}

public extension View {
    /// 확인 다이얼로그를 표시한다.
    ///
    /// ```swift
    /// @State private var dialog: AppDialog?
    ///
    /// Button("삭제") {
    ///     dialog = .delete(itemName: item.title) { viewModel.delete(item) }
    /// }
    /// .appDialog($dialog)
    /// ```
    ///
    /// - Parameter presentation: 기본값 `.confirmation`은 iPad·Mac에서 팝오버로 뜨며
    ///   이 모디파이어가 붙은 뷰에 앵커된다. 트리거 버튼에서 먼 곳(화면 루트 등)에
    ///   붙여야 하는 구조라면 `.alert`를 쓴다.
    func appDialog(
        _ dialog: Binding<AppDialog?>,
        presentation: AppDialogPresentation = .confirmation
    ) -> some View {
        modifier(DialogModifier(dialog: dialog, presentation: presentation))
    }
}

// MARK: - 오류 알럿

/// 사용자에게 보여 줄 수 있는 오류.
public struct AppAlertError: Identifiable {
    public let id = UUID()
    public var title: String
    public var message: String?
    public var retry: (() -> Void)?

    /// - Parameter title: `nil` 이면 "문제가 발생했습니다".
    public init(title: String? = nil, message: String?, retry: (() -> Void)? = nil) {
        self.title = title ?? DesignSystemStrings.genericErrorTitle
        self.message = message
        self.retry = retry
    }
}

private struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppAlertError?

    func body(content: Content) -> some View {
        content.alert(
            error?.title ?? "",
            isPresented: isPresented,
            presenting: error
        ) { current in
            if let retry = current.retry {
                Button(DesignSystemStrings.retry) { retry() }
                Button(DesignSystemStrings.close, role: .cancel) {}
            } else {
                Button(DesignSystemStrings.confirm, role: .cancel) {}
            }
        } message: { current in
            if let message = current.message {
                Text(message)
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { newValue in
                if !newValue {
                    error = nil
                }
            }
        )
    }
}

public extension View {
    /// 오류 알럿을 표시한다. 복구 가능한 오류라면 재시도 버튼이 함께 노출된다.
    func appErrorAlert(_ error: Binding<AppAlertError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
