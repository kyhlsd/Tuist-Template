//
//  AppTextField.swift
//  DesignSystem
//

import SwiftUI

// MARK: - 필드 상태

/// 입력 필드의 검증 상태.
public enum AppFieldState: Equatable {
    case normal
    case error(String)
    case success(String?)

    public var message: String? {
        switch self {
        case .normal: nil
        case let .error(message): message
        case let .success(message): message
        }
    }

    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// MARK: - 컨테이너 모디파이어

/// 텍스트 필드 외형을 담당한다.
///
/// `TextFieldStyle` 프로토콜은 구현에 언더스코어 API(`_body`)를 요구하는
/// 준-비공개 인터페이스라, 안정적인 `ViewModifier`로 대체했다.
private struct FieldContainerModifier: ViewModifier {
    private enum Layout {
        /// 입력 필드는 버튼보다 한 단계 높게 잡아 탭 영역과 텍스트 여유를 늘린다.
        static let extraHeight: CGFloat = 4
    }

    let state: AppFieldState
    let isFocused: Bool

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.metrics.radius.md, style: .continuous)

        content
            .appText(\.bodyLarge, color: isEnabled ? \.textPrimary : \.textDisabled)
            .padding(.horizontal, theme.metrics.spacing.md)
            .frame(minHeight: theme.metrics.minimumHitTarget + Layout.extraHeight)
            .background(isEnabled ? theme.colors.surface : theme.colors.surfaceMuted, in: shape)
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .animation(.app(theme.metrics.duration.fast), value: isFocused)
            .animation(.app(theme.metrics.duration.fast), value: state)
    }

    private var borderColor: Color {
        if state.isError {
            return theme.colors.danger
        }
        if isFocused {
            return theme.colors.accent
        }
        return theme.colors.border
    }

    private var borderWidth: CGFloat {
        (isFocused || state.isError) ? theme.metrics.border.thick : theme.metrics.border.regular
    }
}

public extension View {
    /// 입력 컨트롤에 필드 외형을 적용한다. `TextEditor`, `Picker` 등에도 재사용 가능하다.
    func appFieldContainer(state: AppFieldState = .normal, isFocused: Bool = false) -> some View {
        modifier(FieldContainerModifier(state: state, isFocused: isFocused))
    }
}

// MARK: - AppTextField

/// 라벨 · 입력 · 도움말/오류 메시지를 묶은 표준 텍스트 필드.
public struct AppTextField: View {
    public init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        state: AppFieldState = .normal,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        _text = text
        self.state = state
        self.helperText = helperText
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }

    public let title: String?
    public let placeholder: String
    @Binding public var text: String

    public var state: AppFieldState = .normal
    public var helperText: String?
    public var isSecure: Bool = false
    public var keyboardType: UIKeyboardType = .default
    public var textContentType: UITextContentType?
    public var submitLabel: SubmitLabel = .done
    public var onSubmit: (() -> Void)?

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
            if let title {
                Text(title)
                    .appText(\.bodySmall, color: \.textSecondary)
            }

            field
                .appFieldContainer(state: state, isFocused: isFocused)
                .focused($isFocused)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                // 위의 제목은 별개의 Text 라서 VoiceOver 가 필드 이름으로 읽지 않는다.
                // 제목이 없으면 placeholder 가 이름 역할을 한다.
                .accessibilityLabel(title ?? placeholder)
                .accessibilityHint(helperText ?? "")

            // 오류·성공 문구는 힌트에 넣지 않는다. 힌트는 사용자가 꺼 둘 수 있어서
            // 오류를 놓칠 수 있다. 화면에 보이는 요소로 두고, 바뀔 때 음성으로 알린다.
            if let message = state.message ?? helperText {
                Text(message)
                    .appText(\.caption, color: messageColor)
                    // 도움말은 이미 필드 힌트로 읽히므로 두 번 읽지 않게 숨긴다.
                    .accessibilityHidden(state.message == nil)
                    .transition(.opacity)
            }
        }
        .animation(.app(theme.metrics.duration.fast), value: state)
        .onChange(of: state) { _, newState in
            guard case let .error(message) = newState else { return }
            AppAccessibility.announce(message)
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private var messageColor: KeyPath<ColorTokens, Color> {
        switch state {
        case .normal: \.textTertiary
        case .error: \.danger
        case .success: \.success
        }
    }
}

// MARK: - 검색 필드

/// 지우기 버튼이 포함된 검색 전용 필드.
public struct AppSearchField: View {
    public init(
        placeholder: String,
        text: Binding<String>,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.onSubmit = onSubmit
    }

    public let placeholder: String
    @Binding public var text: String
    public var onSubmit: (() -> Void)?

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.sm) {
            Image(.search)
                .appIcon(\.sm)
                .foregroundStyle(theme.colors.textTertiary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .appText(\.bodyLarge, color: \.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                AppIconButton(
                    icon: .clear,
                    accessibilityLabel: DesignSystemStrings.clearSearch,
                    size: \.sm,
                    tint: \.textTertiary,
                    haptic: nil
                ) {
                    text = ""
                    isFocused = true
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, theme.metrics.spacing.md)
        .frame(minHeight: theme.metrics.minimumHitTarget)
        .background(theme.colors.surfaceMuted, in: Capsule(style: .continuous))
        .animation(.app(theme.metrics.duration.fast), value: text.isEmpty)
    }
}
