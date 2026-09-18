//
//  StateOpacity.swift
//  DesignSystem
//

import Foundation

/// 상태 표현에 쓰는 불투명도.
///
/// 컴포넌트마다 숫자를 즉흥적으로 넣으면 같은 "비활성"이 화면마다 다르게 보이므로 한곳에 모은다.
/// 테마로 바꿀 값이 아니라 컴포넌트 규칙이므로 `MetricTokens` 가 아니라 모듈 내부 상수로 둔다.
enum StateOpacity {
    /// 비활성. 토글, 누를 수 있는 영역, `appDisabled` 로 묶은 영역 모두 같은 값을 쓴다.
    /// 같은 "비활성"이 컴포넌트마다 다르게 흐려 보이지 않도록 하나로 통일했다.
    static let disabled: Double = 0.4
    /// 배경 변화 없이 눌림을 표현하는 컨트롤(칩, 모션 감소 상태의 pressable).
    static let pressed: Double = 0.7
    /// 텍스트 버튼이 눌렸을 때. 글자만 있어 더 크게 흐려야 눌림이 보인다.
    static let pressedText: Double = 0.6
    /// 포커스 링 바깥 후광, 토스트 테두리처럼 강조색을 옅게 까는 곳.
    static let subtleTint: Double = 0.25
}
