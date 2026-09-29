# 결정 기록: refactor/push-image-attachment-rules

계획: [`docs/plans/2026-09-29-push-image-attachment-rules.md`](../plans/2026-09-29-push-image-attachment-rules.md)

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.
계획 문서의 "결정 사항"(옮기는 범위, 타입 모양, 상태 코드 판정, 파일 경로, 동작 보존, 확장자 없는 응답의 MIME 표, Persistence README)도 확정 결정이다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| R-D1 | 확장자 규칙의 각 분기는 그 분기만 타는 입력으로 테스트한다. 요청 URL 분기는 응답 URL(확장자 없음, 리다이렉트된 최종 URL)과 요청 URL(확장자 있음)을 다르게 둔다 (R1-1) | 응답 URL과 요청 URL이 같으면 헤더 없는 `suggestedFilename` 이 URL 확장자를 먼저 돌려줘 요청 URL 분기를 타지 않는다. 요청 URL 줄 삭제와 URL↔MIME 순서 교체 뮤테이션이 이 테스트로만 잡힌다 |
| R-D2 | MIME 표에는 알림 첨부가 받는 형식(JPEG·PNG·GIF)의 표준 타입과, 서버가 흔히 보내는 비표준 별칭 `image/jpg` 를 둔다. 다른 형식은 더하지 않는다 (R1-2) | 계획의 "첨부가 받는 형식만" 결정 안에서 같은 형식의 별칭만 넓혔다. 별칭을 더 넣을지는 실제로 관찰한 서버 응답이 있을 때 정한다 |
| R-D3 | `suggestedFilename` 관련 주석·테스트는 iOS 에서 관찰한 동작을 기준으로 쓰고, 그 점을 주석에 밝힌다 (R1-3) | macOS Foundation 은 확장자 없는 URL 에 `Content-Type` 이 있으면 MIME 확장자를 붙여 돌려주는 등 동작이 다르다. 모듈 테스트는 iOS 시뮬레이터에서 돈다 |

## 라운드 이력

### 1라운드 — 스냅샷 `55a835aed5adcf43531be0b6817fb176205ba869`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Should fix) 요청 URL 확장자 분기를 타는 테스트가 없음 | 반영 | R-D1. `fileURL_redirectedToExtensionlessURL_usesRequestURLExtension` 로 `urlExtensionAndMIMEType_prefersURLExtension` 을 바꾸고, `noHeader_usesURLExtension` 은 실제 분기에 맞게 `noHeader_usesSuggestedFilenameExtension` 으로 이름을 고쳤다. 두 뮤테이션이 각각 실패 1건으로 잡히는 것을 확인. 계획 테스트 표도 갱신 |
| R1-2 (Consider) 비표준 `image/jpg` 가 표에 없음 | 반영(사용자 요청) | R-D2. 표에 한 줄, 매개변수 테스트에 케이스 하나를 더했다. 그 줄을 지우는 뮤테이션이 잡히는 것을 확인. 계획 결정 사항 문구도 고쳤다 |
| R1-3 (Consider) "Unknown" 주석이 플랫폼마다 다름 | 반영(사용자 요청) | R-D3. `fileURL` 문서 주석에 iOS 기준이라는 점과 macOS 차이를 적었다 |
