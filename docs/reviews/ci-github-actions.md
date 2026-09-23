# 리뷰 결정 기록: ci/github-actions

계획: `docs/plans/2026-09-23-github-actions-ci.md`. 계획의 "결정 사항" 표도 확정 결정으로 본다.
단, 아래 D3(캐시)와 D5(동시성)가 계획 표의 "캐시"·"동시성" 행을 구체화하거나 대신한다.

## 확정 결정

| ID | 결정 | 이유 |
|---|---|---|
| D1 | 테스트 스텝에 `-test-timeouts-enabled YES`와 스텝 `timeout-minutes: 45`를 둔다. 잡 타임아웃(60분)은 그대로다 | 잡 타임아웃은 잡을 cancelled로 끝내 `if: failure()` 업로드가 돌지 않는다. 스텝 타임아웃과 xcodebuild 테스트 타임아웃은 failure로 끝나 번들이 올라간다. 스텝 타임아웃으로 끊기면 번들이 불완전할 수 있다는 한계는 받아들인다. 이 보장은 테스트 앞 스텝들이 15분 안에 끝날 때만 성립한다(2라운드 R2-1). 수치는 계획 6단계 실측 전까지 바꾸지 않는다. 실측 없이 바꾸면 다시 추정일 뿐이고, 테스트별 기본 제한(10분)이 대부분의 멈춘 테스트를 먼저 끊는다 |
| D2 | `.xcresult` 업로드 조건은 `failure() && steps.test.outcome == 'failure'`, `overwrite: true` | Release 빌드만 깨졌을 때 통과한 번들을 올리지 않는다(README의 "테스트가 실패하면"과 맞춤). 재실행 시 같은 이름 충돌(409)을 막는다 |
| D3 | `Tuist/.build` 캐시는 `actions/cache/restore` → `tuist install` → `actions/cache/save`(`cache-hit != 'true'`일 때)로 나눈다. 저장 키는 복원 스텝의 `cache-primary-key` | `actions/cache`의 자동 저장은 잡이 성공해야 돈다. 테스트가 깨지는 PR마다 Firebase를 처음부터 받지 않게 한다. 키를 두 번 쓰지 않아 어긋나지 않는다 |
| D4 | xcbeautify는 `mise.toml`에 고정하지 않고 러너 이미지의 것(확인 시점 3.2.1)을 쓴다. `xcbuild.sh`는 `GITHUB_ACTIONS=true`이고 `xcbeautify --help`에 `--renderer`가 있을 때만 렌더러를 붙인다 | 옵션을 모르는 버전이면 xcbeautify가 즉시 끝나 `pipefail`로 모든 실행이 빨개진다. 기능 확인으로 그 경우를 "인라인 주석만 빠짐"으로 낮춘다. mise 고정은 계획 범위 밖(`mise.toml`)이라 후속 결정으로 남긴다 |
| D5 | `concurrency.group`은 PR이면 `github.ref`, 그 밖(main 푸시, 수동 실행)이면 `github.sha` | 같은 그룹이면 `cancel-in-progress: false`여도 대기 중인 실행이 새 실행에 밀려 취소된다. 계획의 "main은 취소하지 않는다"를 실제로 지키려면 커밋마다 그룹이 달라야 한다 |
| D6 | 외부 액션은 모두 커밋 SHA로 고정하고 뒤에 `# vX.Y.Z` 주석을 단다 | 태그가 옮겨져도 검토하지 않은 코드가 돌지 않는다. 서드파티 `jdx/mise-action`이 특히 그렇다. 갱신은 D7 |
| D7 | Dependabot은 `github-actions` 생태계만, 월 1회, 모든 액션을 한 그룹(PR 하나)으로. 커밋 접두어 `ci(deps)`. 계획 5a단계로 추가 | SHA 고정만 하면 보안 수정·Node 런타임 폐기 대응이 멈춘다. 월 1회 묶음으로 PR 소음과 macOS 러너 비용을 줄인다. SPM(Tuist 구조에서 동작 확인 필요)과 `mise.toml`(올리면 포맷·린트 결과가 바뀔 수 있음)은 후속 작업 |
| D8 | CI 테스트 스텝에 `-collect-test-diagnostics never`. 로컬 `xcbuild.sh` 기본값은 그대로(계획 5b단계) | 실패 실행 두 번 모두 마지막 테스트 뒤 10분(≈600초) 동안 번들 로그에 활동이 없었고 로컬은 14초였다. 실패할 때마다 러너 10분을 쓰고 결과가 늦게 나온다. 실패 메시지·위치·세션 로그는 번들에 남는다 |

## 라운드 이력

### 1라운드

- 리뷰 기준 스냅샷: `fd8a1ebdf9f399ef3f50660e9c02a97720788334`
- Blocker, Should fix, 번복 제안: 없음. 사용자 요청으로 Consider 전체를 반영했다.

| 항목 | 처리 | 이유 |
|---|---|---|
| R1-1 멈춘 테스트가 잡 타임아웃까지 가서 번들이 안 올라감 | 반영 | D1 |
| R1-2 테스트 실패 시 `Tuist/.build` 캐시가 저장되지 않음 | 반영 | D3 |
| R1-3 Release 빌드만 실패해도 번들 업로드 | 반영 | D2 |
| R1-4 재실행 시 같은 이름 아티팩트 409 | 반영 | D2 |
| R1-5 xcbeautify만 이미지에 기댐 | 반영 | 확인 결과를 계획 문서 "러너" 전제에 적고, 렌더러 기능 확인을 `xcbuild.sh`에 넣었다. README의 인라인 주석 문장에 조건을 달았다(D4) |
| R1-6 `main`에서 대기 중인 실행이 취소됨 | 반영 | D5. README에도 한 줄 |
| R1-7 액션 태그 참조 | 반영 | SHA 고정(D6). Dependabot은 계획에 없는 새 파일이라 사용자에게 물은 뒤 계획 5a단계로 추가해 반영(D7) |

### 2라운드

- 리뷰 기준 스냅샷: `01ecbbec681fd02c7edeb2454e0549fac26c2218`
- Blocker, Should fix, 번복 제안: 없음

| 항목 | 처리 | 이유 |
|---|---|---|
| R2-1 테스트 앞 단계 여유가 15분뿐이라 잡 타임아웃이 먼저 걸릴 수 있음 | 보류(주석만 반영) | 수치를 바꾸면 D1을 뒤집는다. 사용자 선택으로 `ci.yml` 테스트 스텝 주석에 15분 전제를 적고, 6단계 실측 후 조정하기로 했다(D1 갱신) |

### 3라운드

- 리뷰 기준 스냅샷: `14b673f417acf4bba150e35c98f9c2379ec54fb6`
- Blocker, Should fix, Consider, 번복 제안: 없음. 처리할 항목이 없다.
