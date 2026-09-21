//
//  FittedSheetDetent.swift
//  DesignSystem
//

import SwiftUI

/// `AppFittedSheet`의 detent 계산.
///
/// 뷰 클로저 밖으로 꺼내 두어, 높이가 바뀌는 전환 구간의 판단을 뷰 없이 테스트할 수 있게 한다.
enum FittedSheetDetent {
    /// 시트에 제공할 detent 목록.
    ///
    /// `contentHeight`가 바뀐 뒤 `selection`이 갱신되기까지 한 번의 업데이트 동안
    /// selection이 목록에 없는 detent를 가리키지 않도록, 그 사이에는 이전 값도 목록에 남긴다.
    /// 갱신이 끝나면 두 값이 같아져 Set에서 하나로 합쳐진다.
    static func detents(
        selected: PresentationDetent,
        contentHeight: CGFloat
    ) -> Set<PresentationDetent> {
        [selected, .height(contentHeight)]
    }

    /// 선택된 detent가 콘텐츠 높이와 어긋났을 때 되돌릴 목표. 맞으면 `nil`.
    ///
    /// 전환 중 detent가 두 개인 사이에 사용자가 드래그로 이전 높이를 고르면
    /// 시트가 이전 높이에 머물기 때문에, 콘텐츠 높이로 되돌린다.
    static func correction(
        for selected: PresentationDetent,
        contentHeight: CGFloat
    ) -> PresentationDetent? {
        let fitted = PresentationDetent.height(contentHeight)
        return selected == fitted ? nil : fitted
    }
}
