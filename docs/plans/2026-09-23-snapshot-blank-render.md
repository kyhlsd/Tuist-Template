# 스냅샷 테스트의 빈 렌더(CI 간헐 실패) 수정

## 목표

- CI에서 스냅샷이 실패하면 실제 렌더 이미지가 `.xcresult`(Swift Testing 첨부)와 잡 아티팩트(`__Failures__/`) 양쪽에서 보인다.
- 렌더러가 완전히 투명한 이미지를 돌려주면 "외형이 달라졌습니다(차이 N%)"가 아니라 **빈 렌더**라는 별도 메시지로 실패한다.
- 스냅샷 렌더링이 `ImageRenderer.uiImage` 대신 우리가 만든 비트맵 `CGContext`에 `ImageRenderer.render(rasterizationScale:renderer:)`로 그린다.
- 허용 오차(1%), 테스트 비활성화, 전역 병렬 끄기 없이 로컬 전체 테스트가 통과한다.

## 범위 밖

- `-collect-test-diagnostics never` 변경.
- 허용 오차 조정, 재시도 로직.
- 스냅샷 이외 테스트.

## 전제

### 관찰 (CI 실행 35809183590, 러너 이미지 xcode-27-arm64 20260921.0210)
- `banner` light 51.80%, dark 21.59% 실패, a11y 통과. 스위트 19초(평소 약 5초).
- 기준 이미지 채널 평균(RGBA, premultipliedLast)을 재면 light `(0.5376+0.5119+0.4642+0.5584)/4 = 51.80%`,
  dark `(0.1442+0.1101+0.0510+0.5584)/4 = 21.59%`. `pixelDifference`는 채널 차이 평균이므로,
  **실제 렌더가 크기만 맞고 모든 픽셀이 0(완전 투명)이었다**는 뜻이다. 글꼴·심볼·레이아웃 차이라면 부분 차이가 난다.
- 로컬 재현 시도: 논리 코어 2배의 `yes` 프로세스로 CPU를 포화시킨 채 `-test-iterations 15 -test-repetition-relaunch-enabled YES`로
  스냅샷 스위트를 15분 넘게 돌렸으나 실패 이미지가 한 장도 생기지 않았다(미재현). 가상 GPU 조건은 로컬에서 만들 수 없다.

### 구현 결과 (확인됨)
- CG 경로로 바꾼 뒤 위아래 뒤집기는 필요 없었다(`scaleBy`만).
- a11y 3케이스(AppBanner 4.11%, AppListRow 1.13%, AppSheetHeader 2.82%)가 1%를 넘었다. 차이 지도상 글리프·심볼·모서리
  가장자리에 몰려 있지만, 리뷰에서 지적한 대로 글자 폭(advance)도 조금 좁아졌다(예: AppBanner 본문 끝 약 520px → 508px).
  레이아웃 구조(요소 배치·줄바꿈)는 같다.
- 나머지 18케이스도 허용 오차 0으로 재 보니 0.04%~0.84%로, 같은 체계적 차이가 1% 여유 대부분을 쓰고 있었다.
  러너의 작은 흔들림만으로 다시 간헐 실패할 수 있으므로 **21장 모두 새 경로로 다시 기록**해 기준을 한 렌더 경로로 통일했다.
- 첨부: 한 케이스를 일부러 깨뜨려 `-collect-test-diagnostics never`로 돌리니 `.xcresult`에
  `AppBanner-light-a11y_0_<UUID>.png`가 `ComponentSnapshotTests/banner(condition:)` 첨부로 들어갔다(`xcresulttool export attachments`).
- `__Failures__/`는 `.gitignore`에 이미 있다.

### 원인 분류와 한계
- 분류: 렌더러가 빈 비트맵을 반환(느린 가상 GPU 러너, 스위트 초반 케이스).
- `uiImage`/`cgImage`가 내부적으로 어떤 래스터라이저(Metal/RenderBox)를 쓰는지는 공식 문서에 없다.
  `render(rasterizationScale:renderer:)`는 문서상 "native Core Graphics drawing commands"로 호출자 컨텍스트에 그린다.
  이 경로로 옮기면 불투명한 내부 래스터 경로 의존을 없앤다. 그래도 빈 렌더가 재발하면 새 메시지와 첨부 이미지로 즉시 구분된다.
  - https://developer.apple.com/documentation/swiftui/imagerenderer/render(rasterizationscale:renderer:)

### 변경 지점
- `Modules/Core/DesignSystem/Tests/SnapshotSupport.swift` — `render(...)`, `compare(...)`의 실패 경로.
- `.github/workflows/ci.yml` — `테스트 결과 업로드` 스텝(`if: failure() && steps.test.outcome == 'failure'`).
- `Modules/Core/DesignSystem/Tests/__Snapshots__/*.png` — 렌더 경로가 바뀌어 차이가 허용 오차를 넘으면 재기록.

### API
- `ImageRenderer.render(rasterizationScale:renderer:)` — iOS 16. `@MainActor`. 폴백 불필요(최소 iOS 17).
- Swift Testing `Attachment.record(_ image:named:as:sourceLocation:)` — Swift 6.3 / Xcode 26.4, UIImage 지원(`import Testing` + `import UIKit` 교차 import).
  - https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0014-image-attachments-in-swift-testing-apple-platforms.md
  - 성공한 테스트의 첨부를 지우는 API가 없으므로 **실패 경로에서만** 기록한다.
- 첨부는 `.xcresult`에 들어간다(Xcode 26 릴리스 노트). `-collect-test-diagnostics never`와 무관.

## 결정 사항
| 결정 | 선택 | 이유 |
|---|---|---|
| 렌더 경로 | `render(rasterizationScale:renderer:)` + 직접 만든 RGBA8 premultipliedLast `CGContext` | 문서화된 CG 경로. 비교 함수와 같은 픽셀 형식이라 변환 단계가 줄어든다 (사용자 선택) |
| 빈 렌더 처리 | 알파 전부 0이면 별도 메시지로 실패 | 재시도는 원인을 가린다 |
| 실패 이미지 노출 | 첨부 + 아티팩트 둘 다 | 첨부는 xcresult 하나로 보고, 아티팩트는 xcresult를 열 수 없는 환경에서 PNG 그대로 본다 |
| 아티팩트 경로 | `Modules/**/__Snapshots__/__Failures__/` | `recordRoot`의 기본값(소스 옆). `SNAPSHOT_DIR`은 CI에서 쓰지 않는다 |

## 변경 계획

### 1. 실패 이미지 노출
- `SnapshotSupport.swift`: 비교 실패·빈 렌더일 때 `Attachment.record(rendered, named: "\(identifier).png", as: .png)`. 빈 렌더 판정 함수 추가(RGBA 바이트의 알파 전부 0).
- `ci.yml`: 업로드 스텝 `path`에 `Modules/**/__Snapshots__/__Failures__/` 추가(여러 줄 path).
- 검증: 빌드, 스냅샷 스위트 통과. 첨부 경로는 임시로 한 케이스를 깨뜨려 로컬 xcresult에 첨부가 들어가는지 확인 후 되돌림(커밋하지 않음).

### 2. CGContext 렌더 경로
- `SnapshotSupport.swift` `render(...)`: `ImageRenderer.render(rasterizationScale:)`로 `size * scale` 비트맵 컨텍스트에 그려 `CGImage` → `UIImage(cgImage:scale:orientation:)`.
- 검증: 기존 기준 이미지와 비교. 1% 안이면 기준 유지. 넘으면 `isRecording`으로 재기록 후 전·후 이미지를 눈으로 대조하고 되돌려 끈다.

## 테스트 전략
- 기존 `ComponentSnapshotTests` 21케이스가 새 경로로 통과.
- 빈 렌더 분기는 로컬에서 자연 발생시킬 수 없다. 판정 함수는 순수 함수로 두고 투명·비투명 이미지로 확인하는 작은 테스트를 추가.

## 위험 요소
| 위험 | 가능성 | 대응 |
|---|---|---|
| CG 경로가 일부 효과(블러·머티리얼)를 래스터로 떨어뜨려 픽셀이 달라짐 | 중 | 재기록 후 눈 대조. 현재 컴포넌트엔 머티리얼 없음 |
| CG 경로도 CI에서 빈 렌더 | 낮음~중 | 빈 렌더 메시지 + 첨부로 즉시 식별, 후속 조사 |
| 로컬 기기와 러너 기기 차이로 재기록 이미지가 CI에서 어긋남 | 낮음 | 기존 기준도 로컬 기록이며 CI 통과 이력 있음 |

## 롤백
커밋 단위 revert. 기준 이미지 재기록 커밋은 렌더 경로 커밋과 함께 되돌린다.
