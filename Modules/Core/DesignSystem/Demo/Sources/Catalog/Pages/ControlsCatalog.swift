//
//  ControlsCatalog.swift
//  DesignSystemDemo
//
//  버튼·토글·입력·칩.
//

import DesignSystem
import SwiftUI

struct ControlsCatalog: View {
    /// 칩 예시 문구.
    private static let chipTitles = ["전체", "진행 중", "완료"]

    @Environment(\.theme) private var theme

    @State private var isSwitchOn = true
    @State private var isChecked = false
    @State private var text = ""
    @State private var errorText = "abc"
    @State private var keyword = ""
    @State private var selectedChip = 0

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "Button") {
                VStack(spacing: theme.metrics.spacing.md) {
                    Button("주요 액션") {}
                        .buttonStyle(.appPrimary)
                    Button("보조 액션") {}
                        .buttonStyle(.appSecondary)
                    Button("비활성") {}
                        .buttonStyle(.appPrimary)
                        .disabled(true)
                    HStack(spacing: theme.metrics.spacing.sm) {
                        Button("자세히") {}
                            .buttonStyle(.appTextButton)
                        Button("삭제") {}
                            .buttonStyle(.appTextButton(role: .destructive))
                    }
                }
            }

            CatalogSection(title: "Toggle") {
                VStack(spacing: theme.metrics.spacing.md) {
                    Toggle("스위치", isOn: $isSwitchOn)
                        .toggleStyle(.appSwitch)
                    Toggle("스위치 (비활성)", isOn: .constant(false))
                        .toggleStyle(.appSwitch)
                        .disabled(true)
                    AppDivider()
                    Toggle("체크박스", isOn: $isChecked)
                        .toggleStyle(.appCheckbox)
                }
            }

            CatalogSection(title: "Text Field") {
                VStack(spacing: theme.metrics.spacing.lg) {
                    AppTextField(
                        title: "이메일",
                        placeholder: "name@example.com",
                        text: $text,
                        helperText: "로그인에 사용할 주소를 입력하세요.",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    AppTextField(
                        title: "비밀번호",
                        placeholder: "••••••••",
                        text: $errorText,
                        state: .error("8자 이상 입력해야 합니다."),
                        isSecure: true
                    )
                    AppSearchField(placeholder: "검색", text: $keyword)
                }
            }

            CatalogSection(title: "Chip") {
                HStack(spacing: theme.metrics.spacing.sm) {
                    ForEach(Self.chipTitles.indices, id: \.self) { index in
                        AppChip(
                            text: Self.chipTitles[index],
                            isSelected: selectedChip == index
                        ) {
                            selectedChip = index
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Controls") {
    ControlsCatalog()
        .theme(.standard)
}

#Preview("Controls / Accessibility XXL") {
    ControlsCatalog()
        .theme(.standard)
        .environment(\.dynamicTypeSize, .accessibility2)
}
