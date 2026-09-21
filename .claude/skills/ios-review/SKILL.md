---
name: ios-review
description: 구현이 끝난 Swift 변경분을 격리된 컨텍스트에서 검토하고 심각도별 지적 사항을 돌려줍니다. 커밋이나 PR 전에 사용하세요.
argument-hint: "[비교 기준 ref, 기본값 origin/main]"
context: fork
agent: ios-reviewer
background: false
disable-model-invocation: true
effort: high
---

비교 기준: $ARGUMENTS (비어 있으면 `origin/main`, 없으면 `main`, 그것도 없으면 `HEAD~1`)

## 순서

0. **결정 기록을 읽습니다.** `docs/reviews/$(git branch --show-current | tr / -).md`가 있으면 먼저 읽고,
   에이전트 지침의 "일관성 규칙"대로 확정 결정을 따릅니다. 이번 라운드 번호는 기록의 마지막 라운드 + 1입니다.
   기록이 없으면 1라운드입니다.
   - 기록에 "리뷰 기준 스냅샷"이 있고 `git cat-file -e <스냅샷>`이 성공하면,
     `git diff <스냅샷>`으로 **지난 라운드 이후 바뀐 부분**을 먼저 봅니다.
   - 이번 라운드의 스냅샷을 구해 보고서 맨 위에 적습니다:
     `git stash create` 출력(작업 트리에 변경이 있을 때), 비어 있으면 `git rev-parse HEAD`.
     `git stash create`는 ref나 작업 트리를 건드리지 않고 객체만 만듭니다.
1. 기준 커밋을 정합니다: `git merge-base HEAD <기준>`
2. `git diff --stat <base>`로 변경 규모를 먼저 봅니다
3. 파일이 많으면 **한 번에 전체 diff를 뜨지 말고** 변경량이 큰 것부터 파일 단위로
   `git diff <base> -- <파일>`을 돌려 검토합니다
4. `docs/plans/`의 최근 계획 문서를 읽고 계획에 없는 변경이 섞였는지 확인합니다
5. `swiftlint lint --quiet | grep ': error:'`를 한 번 돌립니다.
   강제 언래핑·`as!`·`try!`·IUO·하드코딩 URL/시크릿·`@unchecked Sendable`·`swiftlint:disable`은
   전부 `error` 심각도라 여기서 기계적으로 잡힙니다. 눈으로 다시 대조하지 마세요.
   편집 훅은 Claude의 Edit/Write만 검사하므로, 사람이 직접 고쳤거나 Bash로 바뀐 파일은
   이 단계에서 처음 걸립니다. 출력이 없으면 "SwiftLint error 없음"으로 적고 넘어갑니다.
   warning은 보지 않습니다(훅 기준과 같게 유지).
6. 린터가 못 잡는 규약만 사람 눈으로 봅니다 — 삼킨 `catch`, `@MainActor` 격리 판단,
   생성자 주입 대신 들어온 하드 의존, 새로 생긴 `.shared`
7. 추가된 분기 중 테스트가 없는 것을 찾습니다

diff 밖의 파일은 문맥 이해에 필요한 만큼만 읽습니다. 전체 코드베이스를 리뷰하지 않습니다.
코드를 수정하지 말고 지적과 수정안만 돌려줍니다.
