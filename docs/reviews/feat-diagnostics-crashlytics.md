# 리뷰 결정 기록 — `feat/diagnostics-crashlytics`

리뷰어(`/ios-review`)는 검토 전에 이 문서를 읽고 "확정 결정"을 따릅니다.
확정 결정을 뒤집으려면 `번복 제안`으로만, 실패 시나리오와 함께 제안합니다.
구현(`/ios-implement`)은 리뷰를 반영한 뒤 이 문서를 갱신합니다.

- 대상: 클라이언트 진단(request ID, breadcrumbs, 비치명 에러 → Firebase Crashlytics). 계획 `docs/plans/2026-09-22-diagnostic-logging.md`

## 확정 결정

**D1. 진단 싱크 선택 분기는 테스트로 고정한다**
- `AppContainer.makeDiagnosticSink(firebaseDecision:logger:)`는 `internal`입니다. `.configure`는 `CrashlyticsDiagnosticSink`, 건너뛴 두 경우는 `LoggerDiagnosticSink`임을 `AppContainerDiagnosticSinkTests`가 확인합니다.
- 이유: Release에서 실제로 수집되는지가 이 분기 하나로 정해집니다. `decision` 테스트만으로는 잘못된 싱크를 골라도 빌드와 테스트가 통과합니다(R1-1).
- `CrashlyticsDiagnosticSink`는 저장 프로퍼티가 없어 만들기만 해서는 Firebase를 부르지 않습니다. 이 성질을 유지해야 Debug 테스트에서 만들 수 있습니다.

**D2. 보고를 묶는 키(`errorType`)에는 enum case 이름을 붙이고, 로그 요약(`summary`)에는 붙이지 않는다**
- `NetworkFailure.errorType`: 연관값이 있는 enum이면 `타입.case`(예: `DecodingError.dataCorrupted`), 아니면 타입 이름입니다. fingerprint와 Crashlytics domain이 이 값을 씁니다.
- case 이름은 `Mirror`의 첫 자식 라벨에서 얻습니다. `String(describing:)`은 `CustomStringConvertible` 설명문(URL이 들어갈 수 있음)을 돌려줄 수 있어 쓰지 않습니다. 연관값은 담지 않습니다.
- 연관값이 없는 case(예: `AuthenticationError.refreshFailed`)는 `Mirror`에 자식이 없어 타입 이름만 남습니다. 알려진 한계입니다. 대부분 보고 대상에서 빠지는 타입이라 받아들였습니다.
- `summary`는 이전 네트워크 브랜치의 결정(에러 로그에는 타입과 코드만)을 그대로 따릅니다.
- 이유: 타입 이름만 쓰면 원인이 다른 에러가 한 이슈로 묶이고, fingerprint별 5분 억제로 첫 원인이 뒤 원인을 가립니다(R1-2).

**D3. 취소는 실패로 다루지 않는다**
- `NetworkFailure.isCancellation`(`CancellationError`, `URLError.cancelled`)을 `NetworkRequestRecord.isCancellation`으로 넘깁니다. 요청 로그는 `info`, breadcrumb은 `.info`로 남깁니다. 보고 대상에서도 빠집니다(기존).
- 오프라인류는 보고하지 않지만 실패이므로 `error`로 남깁니다.
- 이유: 취소를 `error`로 남기면 Crashlytics 로그(세션당 64KB)와 Console의 에러 필터를 차지합니다(R1-4).

**D4. 보고의 operation ID는 실제로 실패한 요청이다**
- 토큰 갱신이 전송 단계에서 실패하면 refresh 클라이언트의 `ClientError`가 다시 감싸지지 않고 올라옵니다. `listItems`를 불렀어도 `refreshToken`으로 보고됩니다. 의도한 동작이며 `RemoteItemRepository` 주석에 적었습니다(R1-3).

**D5. 워크스페이스 스킴은 개발용이다. 배포 아카이브는 앱 스킴으로 만든다**
- `Scheme.workspace()`의 빌드 액션 대상은 모두 아카이브 대상으로도 표시되어, 이 스킴으로 Archive하면 데모 앱까지 묶입니다. 문서 주석과 README에 적었습니다(R1-6).
- 스킴을 직접 정의한 이유는 계획 문서의 결정 사항 "워크스페이스 스킴"을 봅니다.

**D6. 에러 요약 규칙은 `NetworkFailureTests`에서만 검증한다**
- `LoggingMiddleware.summary(of:)`는 지웠습니다. 미들웨어는 `NetworkFailure.describe(_:)`를 직접 부르고, 미들웨어 테스트는 옵저버가 받은 `failureSummary`로 전달만 확인합니다.
- 이유: 같은 규칙을 두 곳에서 테스트하면 규칙을 바꿀 때 두 곳을 고쳐야 하고, 래퍼는 테스트에서만 쓰였습니다(R2-1).

**D7. 비동기 확인 지점용 스트림은 테스트가 소비 쪽을 소유한다**
- 테스트 대역(`StreamingSink`)은 `AsyncStream.Continuation`만 들고, 스트림과 iterator는 테스트 함수가 만듭니다.
- 이유: `AsyncStream`은 소비자를 하나만 지원합니다. 대역이 부를 때마다 iterator를 만들면 두 번 받는 테스트에서 동작이 보장되지 않고, 대역에 iterator를 두면 가변 상태가 생겨 `Sendable`과 부딪칩니다(R2-2).

## 라운드 이력

### 1라운드 — 스냅샷 `e52a5bcbe6d3c7d8f662daeb92518f46793c7a0c`

| 항목 | 처리 | 이유 |
|---|---|---|
| R1-1 싱크 선택 분기 테스트 없음 | 반영 | `makeDiagnosticSink`를 `internal`로 올리고 `AppContainerDiagnosticSinkTests` 추가(D1) |
| R1-2 URLError가 아닌 에러가 한 fingerprint로 묶임 | 반영(사용자 요청) | `errorType`에 case 이름 추가, `summary`는 유지(D2). 테스트 3개 추가 |
| R1-3 refresh 전송 실패의 operation ID | 반영(사용자 요청) | 의도한 동작으로 보고 주석에 적음(D4) |
| R1-4 취소가 error 레벨로 남음 | 반영(사용자 요청) | `isCancellation` 추가, 로그 `info`와 breadcrumb `.info`(D3). 테스트 4개 추가 |
| R1-5 `report(_:)` 진입점 테스트 없음 | 반영(사용자 요청) | 스트림 싱크를 확인 지점으로 쓰는 테스트 추가. 고정 대기 없음 |
| R1-6 워크스페이스 스킴 Archive | 반영(사용자 요청) | `archiveAction`은 두고 문서 주석과 README에 "배포 아카이브는 앱 스킴으로"를 적음(D5). 빼면 Xcode의 Archive 동작이 어떻게 바뀌는지 확인하지 않았다 |
| R1-7 테스트 프로퍼티 뒤 빈 줄 | 반영(사용자 요청) | 빈 줄 추가 |
| R1-8 계획 문서의 `configureIfAvailable` 반환형 | 반영(사용자 요청) | 계획 문서를 `Decision` 반환으로 고침. `errorType`, `isCancellation` 필드 설명도 함께 맞춤 |

### 2라운드 — 스냅샷 `c6846e72e3e5931c28921c9e001a07c4edd0bfd6`

| 항목 | 처리 | 이유 |
|---|---|---|
| R2-1 `summary(of:)`가 테스트에서만 쓰임 | 반영(사용자 요청) | 래퍼와 파라미터 테스트를 지우고, `NetworkFailureTests`에 없던 두 경우(감싼 `AuthenticationError`, 감싸지 않은 `URLError`)의 요약 테스트를 옮김(D6). 계획 문서 2단계에 적음 |
| R2-2 `StreamingSink.next()`가 매번 iterator를 만듦 | 반영(사용자 요청) | 문서 주석 대신 구조를 바꿈. 대역은 continuation만 들고 테스트가 iterator를 소유(D7) |

### 3라운드 — 스냅샷 `96054e942002011b698c2244fb52214cd8cca52d`

지적 없음. R2-1(D6)과 R2-2(D7)가 결정대로 반영된 것을 확인했다.
