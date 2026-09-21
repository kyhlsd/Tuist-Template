# 리뷰 결정 기록 — `fix/design-system-review`

리뷰어(`/ios-review`)는 검토 전에 이 문서를 읽고 "확정 결정"을 따릅니다.
확정 결정을 뒤집으려면 `번복 제안`으로만, 실패 시나리오와 함께 제안합니다.
구현(`/ios-implement`)은 리뷰를 반영한 뒤 이 문서를 갱신합니다.

- 대상: `Modules/Core/DesignSystem` (계획 문서 없이 만든 모듈의 사후 리뷰)
- 리뷰 기준 스냅샷: 없음 — 1~6라운드는 이 기록이 생기기 전이라 스냅샷을 남기지 않았습니다.
  7라운드는 전체 diff를 보되 아래 확정 결정을 따릅니다.

## 확정 결정

각 항목의 "이력"은 판단이 바뀐 경로입니다. 최종 판단과 그 이유가 기준입니다.

**D1. `AsyncButton` 중복 실행 방지**
- 작업은 실제로 끝날 때까지 실행 중으로 봅니다. `cancel()`은 취소만 요청하고 참조를 지우지 않습니다(`AsyncTaskRunner`).
- 잠금은 같은 뷰 identity 안에서만 유지됩니다. 화면이 새로 만들어지는 경우는 문서로 안내하고,
  반드시 막아야 하는 작업은 ViewModel이 실행 상태를 가지도록 안내합니다. 구조로 막지 않습니다.
- 햅틱은 `start(_:onStart:)`의 `onStart`에서 재생합니다. 거부된 탭에서는 울리지 않습니다.
- 디버그 빌드에서는 취소 후 10초가 넘게 잠겨 있으면 로그를 남깁니다. 시간 의존이라 테스트하지 않습니다.
- 이력: R1 취소 가드 → R3 "취소 즉시 풀면 이중 요청" → 끝날 때까지 잠금 → R6 identity 범위 문서화

**D2. 햅틱 주입**
- 전역 싱글턴·전역 설정을 두지 않고 환경값 `\.hapticPlayer`로 주입합니다. 끄기는 루트에서 `.hapticPlayer(nil)`입니다.
- 기본 재생기는 파일 전용 전역 인스턴스 하나입니다. `@Entry`는 기본값을 읽을 때마다 다시 평가하기 때문입니다.
- `SystemHapticPlayer`는 타입째 `internal`입니다. 모듈 밖에서 만들면 생성기 캐시가 여러 벌이 되기 때문입니다.
- `prepare(_:)`는 프로토콜 요구사항이고 빈 기본 구현을 둡니다.
- 이력: R1 주입 전환 → R5 init 비공개 → R6 타입 비공개

**D3. 햅틱 재생 판단과 테스트 범위**
- 재생 여부 판단은 `playIfEnabled` / `prepareIfEnabled`(public)와 `AsyncTaskRunner.start(_:onStart:)`에 모으고, 여기만 테스트합니다.
- 뷰를 띄워야만 확인할 수 있는 연결(`.appHaptic`, `AppIconButton`, `AppPressableStyle`의 `isPressed && isEnabled`,
  재생기 `nil`)은 테스트하지 않고 `HapticPlayingTests` 주석에 그렇다고 적어 둡니다.
- **불리언 조건 하나를 테스트하려고 함수로 꺼내지 않습니다.** 진리표를 다시 쓰는 테스트가 되기 때문입니다.
- 이력: R5 `playsHaptic` 분리 → R6 인라인으로 되돌림(이 결정이 최종)

**D4. 대비율과 반투명 색**
- `ratio(_:_:in:)`(순서 무관, 불투명 전용): 반투명 입력은 API를 잘못 고른 것으로 봅니다.
  디버그 빌드에서는 `assertionFailure`, 릴리스 빌드에서는 최저값 `1`을 돌려줘 어떤 기준도 통과하지 않게 합니다.
- `ratio(foreground:background:in:)`: 반투명 전경은 배경과 합성해 계산합니다. 반투명 배경은 정상 입력이므로
  멈추지 않고 `nil`을 돌려줍니다(`overlay` 같은 반투명 토큰이 실제로 있습니다).
- `meets` / `meetsNonTextRequirement`는 반투명 배경이면 `false`입니다. `Report.ratio`는 `Double?`이고,
  `verdict`(pass / fail / indeterminate)로 판정 불가를 미달과 구분해 표시합니다.
- 불투명 판정은 알파 `1 - 1e-4` 이상입니다(색 공간 변환 오차 흡수).
- `relativeLuminance`는 `internal`입니다.
- 이력: R2 assert → R5 릴리스 `1` 반환 → R6 foreground/background 쪽만 `Double?`

**D5. `AppFittedSheet` detent**
- 전환 중에는 이전 selection도 detent 목록에 남기고, 사용자가 이전 높이를 고르면 콘텐츠 높이로 되돌립니다.
  판단은 `FittedSheetDetent`에 있습니다.
- 테스트는 두 `onChange`를 순서대로 흉내 내는 **수렴 시나리오**로 합니다. "집합에 원소가 들어 있다" 류는 두지 않습니다.
- 긴 콘텐츠(시스템이 높이를 제한하는 경우)는 시뮬레이터에서 확인했습니다. 되돌리기 반복은 없었습니다.
- 이력: R1 전환 중 detent 추가 → R2 selection 보정 → R3 함수 분리 → R4·R5·R6 테스트 형태가 세 번 바뀜(수렴 시나리오가 최종)

**D6. 시트 닫기 버튼**
- `AppSheetHeader`의 닫기 버튼은 `AppIconButton(background:)`을 씁니다.
- 스냅샷 테스트(`AppSheetHeader`, `AppIconButton`)가 있고, 다크 모드가 보이도록 `.appScreenBackground()`를 깝니다.

**D7. 이 브랜치의 테스트 판단 기준**
- `#expect`가 없는 테스트는 두지 않습니다.
- 구현 식을 그대로 옮겨 적은 테스트는 두지 않습니다. 동작 시나리오나 알려진 경계값(예: `#767676`/흰색 ≈ 4.54)으로 검증합니다.
- 테스트할 수 없는 경로는 억지로 구조를 바꾸지 않고, 테스트하지 않는다는 사실을 주석으로 남깁니다(D3).

**D8. 범위**
- `AppToastQueueTests.swift`는 R1 Should fix로 추가한 것이며 유지합니다. 범위가 섞이는 문제는 커밋을 나눠 해결합니다(보류 항목 참고).
- 스냅샷 스위트의 기존 15건 실패는 이 브랜치 이전부터 있던 것입니다(`main`에서도 같음). 이 브랜치의 범위가 아닙니다.

## 보류

- **커밋 분리**: 설정 변경(`.claude/`), 버그 수정·테스트, 햅틱 API 변경(파괴적)으로 나눕니다. 사용자 결정을 기다리는 중입니다.
- **`Color(light:dark:)` MainActor 크래시**: 이 브랜치 이전부터 있던 버그로, 별도 작업으로 분리했습니다.

## 라운드 이력

| 라운드 | 스냅샷 | 처리 |
|---|---|---|
| R1 | — | Should fix 4 · Consider 3 전부 반영 |
| R2 | — | Should fix 4 중 3 반영, 커밋 분리는 보류. Consider 3 반영 |
| R3 | — | 전부 반영 |
| R4 | — | 8 반영, 커밋 분리 보류 |
| R5 | — | 8 반영, 커밋 분리 보류 |
| R6 | — | 9 반영(R5 결정 일부 번복: D3, D4, D5), 커밋 분리 보류. 이후 이 기록 도입 |
