# 결정 기록: fix/review-home-cancel-retry-test

계획: 없음. `main` 전체 리뷰(1라운드) 결과를 입력으로 삼았다.

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| R-D1 | `HomeViewModel.load()` 는 실패했을 때 `Task.isCancelled` 이면 `.failed` 대신 `.idle` 로 되돌린다. 에러는 화면 상태로 쓰지 않는다 (R1-1) | `HomeView` 의 `.task` 는 `.idle` 일 때만 다시 부른다. 탭 전환이나 딥링크로 로딩 중에 화면이 사라진 취소를 `.failed` 로 남기면, 돌아와도 다시 불러오지 않는다. persistence D5("취소된 호출은 결과를 버린다")와 같은 방향이다. 에러의 종류(`URLError.cancelled` 가 매핑된 `.unavailable`)로 판단하지 않는 이유가 있다. 도메인 에러에는 취소 정보가 남지 않기 때문이다 |
| R-D2 | 취소 테스트 대역은 `Task.sleep` 대신, continuation 을 붙들어 둔 `AsyncStream` 을 반복하다가 취소될 때 끝난다 (R1-1) | 테스트 규약이 sleep·고정 대기를 금지한다. 스트림은 시계에 의존하지 않고, 태스크가 취소될 때에만 반복이 끝난다. 대역을 기다리는 테스트에는 `.timeLimit(.minutes(1))` 을 건다. `load()` 가 대역을 부르지 않게 바뀌면 멈추지 않고 실패하게 하기 위해서다(기존 스트림 대기 테스트와 같은 방식) (R2-1) |
| R-D3 | RetryMiddleware 의 body 재사용 조건은 PUT + `.multiple`(재시도함) / PUT + `.single`(재시도 안 함) 짝 테스트로 고정한다 (R2-2) | `.single` 테스트만 두면 `.put` 이 멱등 목록에서 빠져도 통과한다. 짝이 있어야 body 조건만 따로 검증된다 |

## 라운드 이력

### 1라운드 — 스냅샷 `3c34c5fb9e0ded73c5983adfc3fe92d6941650b5`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Should fix) 취소된 로드가 `.failed` 로 남음 | 반영 | R-D1. `load_cancelled_returnsToIdle` 추가. 수정을 되돌리면 이 테스트가 실패하는 것을 확인 |
| R1-2 (Consider) RetryMiddleware body 재사용 조건 테스트 없음 | 반영 | 사용자가 반영을 요청했다. `intercept_singleIterationBody_doesNotRetry`(PUT + `.single` body + 503) 추가. `isReplayable` 조건을 빼면 실패하는 것을 확인 |

### 2라운드 — 스냅샷 `4b8e56a24c5b608058efefa6b4d82a3f7c024fec`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R2-1 (Consider) 취소 테스트가 끝없이 기다릴 수 있음 | 반영 | 사용자가 반영을 요청했다. `.timeLimit(.minutes(1))` 추가. R-D2 갱신 |
| R2-2 (Consider) PUT 재시도 전제를 검증하지 않음 | 반영 | 사용자가 반영을 요청했다. `intercept_multipleIterationBody_retries` 추가. `.put` 을 멱등 목록에서 빼면 이 테스트가 실패하는 것을 확인. R-D3 |
