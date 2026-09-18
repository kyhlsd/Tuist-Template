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

1. 기준 커밋을 정합니다: `git merge-base HEAD <기준>`
2. `git diff --stat <base>`로 변경 규모를 먼저 봅니다
3. 파일이 많으면 **한 번에 전체 diff를 뜨지 말고** 변경량이 큰 것부터 파일 단위로
   `git diff <base> -- <파일>`을 돌려 검토합니다
4. `docs/plans/`의 최근 계획 문서를 읽고 계획에 없는 변경이 섞였는지 확인합니다
5. `.claude/rules/swift.md` 위반이 남았는지 확인합니다
   (강제 언래핑, 하드코딩, `@unchecked Sendable`, 삼킨 에러)
6. 추가된 분기 중 테스트가 없는 것을 찾습니다

diff 밖의 파일은 문맥 이해에 필요한 만큼만 읽습니다. 전체 코드베이스를 리뷰하지 않습니다.
코드를 수정하지 말고 지적과 수정안만 돌려줍니다.
