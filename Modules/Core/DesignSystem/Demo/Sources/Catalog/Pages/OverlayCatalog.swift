//
//  OverlayCatalog.swift
//  DesignSystemDemo
//
//  토스트·배너·시트·다이얼로그·햅틱.
//

import DesignSystem
import SwiftUI

struct OverlayCatalog: View {
    private enum Layout {
        /// 콘텐츠 높이 시트가 늘고 줄어드는 모습을 보기 위한 항목 수 범위.
        static let fittedItemRange = 1 ... 20
        static let sheetOptionCount = 6
        static let hapticButtonMinWidth: CGFloat = 90
    }

    @Environment(\.theme) private var theme
    @Environment(\.hapticPlayer) private var hapticPlayer

    @State private var toast: AppToast?
    @State private var dialog: AppDialog?
    @State private var centeredDialog: AppDialog?
    @State private var error: AppAlertError?
    @State private var isSheetPresented = false
    @State private var isFittedSheetPresented = false
    @State private var fittedItemCount = 3
    @State private var isOffline = false
    @State private var isBannerVisible = true

    var body: some View {
        CatalogScroll {
            CatalogSection(title: "Toast") {
                VStack(spacing: theme.metrics.spacing.sm) {
                    Button("성공 토스트") {
                        toast = .success("저장했습니다")
                    }
                    .buttonStyle(.appSecondary)

                    Button("오류 토스트 (재시도)") {
                        toast = .error(
                            "저장에 실패했습니다",
                            message: "네트워크 연결을 확인해 주세요.",
                            retry: { toast = .success("다시 시도했습니다") }
                        )
                    }
                    .buttonStyle(.appSecondary)

                    Button("안내 토스트") {
                        toast = .info("링크를 복사했습니다")
                    }
                    .buttonStyle(.appSecondary)
                }
            }

            CatalogSection(title: "Banner") {
                VStack(spacing: theme.metrics.spacing.md) {
                    ForEach(AppMessageKind.allCases, id: \.self) { kind in
                        AppBanner(
                            kind: kind,
                            title: "\(kind.accessibilityPrefix) 배너",
                            message: "조건이 유지되는 동안 계속 표시됩니다."
                        )
                    }

                    if isBannerVisible {
                        AppBanner(
                            kind: .info,
                            title: "닫을 수 있는 배너",
                            action: AppMessageAction(title: "자세히 보기") {},
                            onDismiss: { isBannerVisible = false }
                        )
                    }
                }
            }

            CatalogSection(title: "Status Banner (아래 배치)") {
                Toggle("배너 표시", isOn: $isOffline)
                    .toggleStyle(.appSwitch)
            }

            CatalogSection(title: "Sheet") {
                VStack(spacing: theme.metrics.spacing.sm) {
                    Button("바텀시트 열기 (detent 지정)") { isSheetPresented = true }
                        .buttonStyle(.appPrimary)

                    Button("바텀시트 열기 (콘텐츠 높이)") { isFittedSheetPresented = true }
                        .buttonStyle(.appSecondary)

                    Stepper(
                        "항목 개수: \(fittedItemCount)",
                        value: $fittedItemCount,
                        in: Layout.fittedItemRange
                    )
                    .appText(\.bodySmall, color: \.textSecondary)
                }
            }

            CatalogSection(title: "Dialog") {
                VStack(spacing: theme.metrics.spacing.sm) {
                    // 팝오버가 버튼에 앵커되도록 모디파이어를 트리거 옆에 붙인다.
                    Button("삭제 확인 (팝오버)") {
                        dialog = .delete(itemName: "샘플 항목") {
                            toast = .success("삭제했습니다")
                        }
                    }
                    .buttonStyle(.appSecondary)
                    .appDialog($dialog)

                    // 앵커가 필요 없는 형태. 어디에 붙여도 화면 중앙에 뜬다.
                    Button("변경 사항 취소 (알럿)") {
                        centeredDialog = .discardChanges {}
                    }
                    .buttonStyle(.appSecondary)
                    .appDialog($centeredDialog, presentation: .alert)

                    Button("오류 알럿") {
                        error = AppAlertError(
                            message: "서버에 연결할 수 없습니다.",
                            retry: {}
                        )
                    }
                    .buttonStyle(.appSecondary)
                }
            }

            CatalogSection(title: "Haptic") {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: Layout.hapticButtonMinWidth), spacing: theme.metrics.spacing.sm),
                    ],
                    spacing: theme.metrics.spacing.sm
                ) {
                    ForEach(AppHaptic.allCases, id: \.self) { haptic in
                        Button(String(describing: haptic)) {
                            hapticPlayer.playIfEnabled(haptic)
                        }
                        .buttonStyle(.appSecondary(size: .small))
                    }
                }
            }
        }
        // 화면 콘텐츠에 붙였으므로 내비게이션 바 아래에 표시된다.
        .appStatusBanner(
            isPresented: isOffline,
            title: "이 화면에만 표시되는 배너",
            placement: .belowNavigationBar
        )
        .appToast($toast)
        .appErrorAlert($error)
        .appFittedSheet(isPresented: $isFittedSheetPresented) {
            AppSheetHeader(
                title: "정렬 기준",
                subtitle: "콘텐츠 높이에 맞춰 열립니다",
                onClose: { isFittedSheetPresented = false }
            )

            ForEach(0 ..< fittedItemCount, id: \.self) { index in
                AppListRow(icon: .filter, title: "항목 \(index + 1)")
                if index < fittedItemCount - 1 {
                    AppDivider()
                }
            }
        }
        .appSheet(isPresented: $isSheetPresented, detents: [.medium, .large]) {
            AppSheetContainer {
                AppSheetHeader(
                    title: "필터",
                    subtitle: "조건을 선택하세요",
                    onClose: { isSheetPresented = false }
                )

                ForEach(0 ..< Layout.sheetOptionCount, id: \.self) { index in
                    AppListRow(icon: .filter, title: "옵션 \(index + 1)")
                    AppDivider()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Overlay") {
    OverlayCatalog()
        .theme(.standard)
}

#Preview("Overlay / Dark") {
    OverlayCatalog()
        .theme(.standard)
        .preferredColorScheme(.dark)
}
