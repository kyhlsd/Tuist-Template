//
//  FittedSheetDetentTests.swift
//  DesignSystemTests
//

@testable import DesignSystem
import SwiftUI
import Testing

@Suite("콘텐츠 높이 시트 detent")
struct FittedSheetDetentTests {
    /// `AppFittedSheet`의 두 `onChange`를 실제 순서대로 흉내 낸다.
    /// 높이 변경 → selection을 새 높이로 맞춤 → 사용자가 드래그로 이전 높이를 고름 → 보정.
    /// 끝나면 selection이 콘텐츠 높이에 있고 detent 목록이 하나로 합쳐져야 한다.
    @Test
    func correction_높이변경후드래그로이전높이선택_목록이하나로수렴() throws {
        let previousHeight: CGFloat = 200
        let contentHeight: CGFloat = 320
        var selected = PresentationDetent.height(previousHeight)

        selected = .height(contentHeight) // onChange(of: contentHeight)
        selected = .height(previousHeight) // 전환 중 사용자가 이전 높이로 드래그
        selected = try #require(FittedSheetDetent.correction(for: selected, contentHeight: contentHeight))

        #expect(FittedSheetDetent.detents(selected: selected, contentHeight: contentHeight).count == 1)
    }

    /// `onChange(of: contentHeight)`가 selection을 새 높이로 맞추면 `onChange(of: selectedDetent)`가 다시 불린다.
    /// 이때 보정이 또 나오면 두 핸들러가 서로 되돌리기를 반복한다.
    /// 화면보다 긴 콘텐츠(시스템이 높이를 제한하는 경우)도 포함한다.
    @Test(arguments: [0, 200, 320, 5000] as [CGFloat])
    func correction_높이변경핸들러가selection갱신_추가보정없음(height: CGFloat) {
        let selectedByHeightHandler = PresentationDetent.height(height)

        let correction = FittedSheetDetent.correction(for: selectedByHeightHandler, contentHeight: height)

        #expect(correction == nil)
    }

    /// 전환 중 사용자가 드래그로 이전 높이를 고른 경우: 한 번 보정하면 그 결과에는 더 보정할 것이 없어야 한다.
    @Test
    func correction_이전높이선택됨_한번보정후수렴() throws {
        let contentHeight: CGFloat = 320

        let corrected = try #require(FittedSheetDetent.correction(for: .height(200), contentHeight: contentHeight))

        #expect(corrected == .height(contentHeight))
        #expect(FittedSheetDetent.correction(for: corrected, contentHeight: contentHeight) == nil)
    }
}
