---
name: ios-platform-research
description: Apple 플랫폼에서 이 기능을 어떻게 구현하는 게 맞는지 조사합니다. API 가용성, 프레임워크 선택, 함정을 확인해 접근법 후보로 돌려줍니다. 백그라운드로 돌아가므로 /ios-research와 동시에 띄울 수 있습니다.
argument-hint: <구현할 기능>
context: fork
agent: ios-platform-researcher
disable-model-invocation: true
---

기능: $ARGUMENTS

이 기능을 Apple 플랫폼에서 어떻게 구현하는 게 맞는지 조사하고,
당신의 보고 형식대로 접근법 후보와 트레이드오프를 돌려주세요.

먼저 최소 지원 버전과 기존 의존성을 확인하고 시작합니다. 그게 모든 답의 전제입니다.
API 시그니처와 도입 버전은 반드시 공식 문서에서 확인하고 출처 URL을 답니다.
저장소 내부 구조는 보지 않습니다. 그건 다른 조사가 맡습니다.
