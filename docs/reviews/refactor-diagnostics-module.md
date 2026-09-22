# 리뷰 결정 기록: refactor/diagnostics-module

계획: `docs/plans/2026-09-22-diagnostics-module.md`. 계획의 "결정 사항" 표(모듈 분리, Networking은 옵저버 유지,
변환은 Data, `LoggerDiagnosticSink` 공개, Diagnostics는 Foundation과 `os`만)도 확정 결정으로 본다.

## 확정 결정

| ID | 결정 | 이유 |
|---|---|---|
| D1 | `LoggerDiagnosticSink`의 로그 문구를 `static func message(for: Breadcrumb)`, `message(for: DiagnosticFailure)`(internal)로 분리해 `DiagnosticsTests`에서 테스트한다. 레벨 분기(info/error)와 실제 `Logger` 출력은 테스트하지 않는다 | `os.Logger` 출력은 테스트에서 읽을 수 없다. Console에서 읽는 문구가 공개 기본 구현의 계약이므로 문구만 고정한다. 로거를 프로토콜로 감싸는 것은 이 이동 작업에 비해 과하다 |
| D2 | 문구 분리 뒤에는 이미 만든 문자열 전체를 `privacy: .public` 하나로 남긴다 | 이전에도 모든 필드를 `.public`으로 남겼으므로 Console 출력은 같다. 필드가 모두 요약값이라는 전제(`DiagnosticFailure` 문서 주석)는 그대로다 |
| D3 | 매니페스트의 의존성 줄에는 명시적 의존성 검사 때문에 필요한 이유를 주석으로 단다 | 중복처럼 보여 지워지는 것을 막는다(`Data/Project.swift`의 `testDependencies`) |
| D4 | `NetworkActivityObserving.swift`의 주석 한 줄("Domain 을 모르므로" → "Diagnostics 를 모르므로")만 계획 범위 밖에서 고쳤다 | 사용자 요청. 모듈 이동으로 틀린 설명이 됐다. Networking 구조는 그대로다 |
| D5 | 로그 문구의 빈 값 표시(`LoggerDiagnosticSink`의 `Placeholder.missing`)와 fingerprint 키의 빈 값(`DiagnosticFailure`의 `Fingerprint.missing`)은 값이 같아도 따로 둔다 | 용도가 다르다. 하나를 바꾸면 Console 문구나 중복 억제 키가 함께 바뀌는 결합을 만들지 않는다 |

## 라운드 이력

### 1라운드

- 리뷰 기준 스냅샷: `4cef6ec15b0e0b09b7e275c23ff65386b99e9a2e`
- Blocker, Should fix, 번복 제안: 없음

| 항목 | 처리 | 이유 |
|---|---|---|
| R1-1 `Data/Project.swift` 테스트 의존성 `.module(.diagnostics)`에 이유 주석 | 반영 | 사용자 요청. D3 |
| R1-2 `LoggerDiagnosticSink` 테스트 부재 | 반영 | 사용자 요청. 문구를 분리해 `LoggerDiagnosticSinkTests` 3개를 추가했다(D1, D2) |

### 2라운드

- 리뷰 기준 스냅샷: `16832c97bfaae46bb71dc90ffb734a71b3317324`
- Blocker, Should fix, 번복 제안: 없음

| 항목 | 처리 | 이유 |
|---|---|---|
| R2-1 `Placeholder.missing`과 `Fingerprint.missing`이 같은 `"-"` | 기각(변경 없음) | 리뷰도 "합칠 필요 없음"으로 결론냈다. D5 |
