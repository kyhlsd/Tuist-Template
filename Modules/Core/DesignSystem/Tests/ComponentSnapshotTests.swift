//
//  ComponentSnapshotTests.swift
//  DesignSystemTests
//
//  ⚠️ 테스트 타깃에 포함한다.
//  최초 실행 전 `Snapshot.isRecording = true`로 기준 이미지를 생성한 뒤 다시 끈다.
//

@testable import DesignSystem
import SwiftUI
import Testing

/// 실기기에서는 기준 이미지를 읽고 쓸 수 없으므로 스위트 전체를 건너뛴다.
/// 나머지 테스트는 기기에서도 정상 실행된다.
@Suite(
    "컴포넌트 스냅샷",
    .enabled(
        if: Snapshot.isSupportedEnvironment,
        "스냅샷 테스트는 시뮬레이터에서만 실행됩니다"
    )
)
@MainActor
struct ComponentSnapshotTests {
    /// 라이트·다크·접근성 확대를 함께 확인한다.
    ///
    /// 외형 회귀는 다크 모드와 접근성 확대에서 가장 자주 발생하는데,
    /// 개발 중에는 라이트 모드 기본 크기만 보게 되므로 놓치기 쉽다.
    ///
    /// `@Test(arguments:)` 는 nonisolated 문맥에서 평가되므로 메인 액터에서 풀어 둔다.
    /// 값이 전부 Sendable 이라 안전하다.
    private nonisolated static let conditions: [(name: String, scheme: ColorScheme, size: DynamicTypeSize)] = [
        ("light", .light, .large),
        ("dark", .dark, .large),
        ("a11y", .light, .accessibility2),
    ]

    @Test("배너", arguments: conditions)
    func banner(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            AppBanner(
                kind: .warning,
                title: "확인이 필요합니다",
                message: "설정에서 알림 권한을 허용해 주세요.",
                action: AppMessageAction(title: "설정 열기") {}
            )
            .padding(),
            named: "AppBanner",
            size: CGSize(width: 320, height: 180),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    @Test("버튼", arguments: conditions)
    func buttons(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            VStack(spacing: 12) {
                Button("주요 액션") {}
                    .buttonStyle(.appPrimary)
                Button("보조 액션") {}
                    .buttonStyle(.appSecondary)
                Button("비활성") {}
                    .buttonStyle(.appPrimary)
                    .disabled(true)
            }
            .padding(),
            named: "Buttons",
            size: CGSize(width: 320, height: 220),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    @Test("목록 행", arguments: conditions)
    func listRow(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            VStack(spacing: 0) {
                AppListRow(icon: .person, title: "계정", subtitle: "프로필과 로그인 정보")
                AppDivider(inset: \.xxxl)
                AppListRow(icon: .bell, title: "알림") {
                    AppRowDetail(text: "켬")
                }
            }
            .padding(),
            named: "AppListRow",
            size: CGSize(width: 320, height: 200),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    @Test("배지", arguments: conditions)
    func badges(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            VStack(alignment: .leading, spacing: 8) {
                AppBadge(text: "기본")
                AppBadge(text: "완료", style: .success, icon: .success)
                AppBadge(text: "오류", style: .danger)
            }
            .padding(),
            named: "AppBadge",
            size: CGSize(width: 240, height: 160),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    @Test("상태 화면", arguments: conditions)
    func statusView(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            AppStatusView.empty(
                title: "아직 항목이 없습니다",
                message: "오른쪽 위 버튼으로 첫 항목을 추가해 보세요.",
                action: AppStatusAction(title: "항목 추가") {}
            ),
            named: "AppStatusView",
            size: CGSize(width: 320, height: 420),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    /// 닫기 버튼이 `AppIconButton(background:)`로 바뀌었으므로 원형 배경의 크기(44pt)와 위치를 고정한다.
    @Test("시트 헤더", arguments: conditions)
    func sheetHeader(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            AppSheetHeader(title: "정렬 기준", subtitle: "콘텐츠 높이에 맞춰 열립니다") {}
                .padding()
                // 하네스는 배경을 칠하지 않으므로, 다크 모드 외형이 보이도록 화면 배경을 깐다.
                .appScreenBackground(),
            named: "AppSheetHeader",
            size: CGSize(width: 320, height: 160),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }

    @Test("아이콘 버튼", arguments: conditions)
    func iconButtons(condition: (name: String, scheme: ColorScheme, size: DynamicTypeSize)) {
        let failure = Snapshot.compare(
            HStack(spacing: 16) {
                AppIconButton(icon: .close, accessibilityLabel: "닫기") {}
                AppIconButton(
                    icon: .close,
                    accessibilityLabel: "닫기",
                    size: \.sm,
                    tint: \.textSecondary,
                    background: \.surfaceMuted
                ) {}
            }
            .padding()
            .appScreenBackground(),
            named: "AppIconButton",
            size: CGSize(width: 200, height: 120),
            colorScheme: condition.scheme,
            dynamicTypeSize: condition.size
        )

        #expect(failure == nil, "\(failure ?? "")")
    }
}
