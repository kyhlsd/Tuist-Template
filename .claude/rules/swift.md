---
description: Swift 소스 파일 작성 규약
paths: "**/*.swift"
---

# Swift 규약

## 옵셔널

- 강제 언래핑(`!`), `as!`, `try!`를 쓰지 않습니다.
- 암시적 언래핑 옵셔널(`Type!`)도 쓰지 않습니다. 예외는 `@IBOutlet` 하나뿐입니다
  (SwiftLint `implicitly_unwrapped_optional`의 기본 동작과 같습니다).
- `guard let` / `if let` / `??`로 처리하고, 실패가 프로그래밍 오류인 경우에만
  `preconditionFailure(_:)`로 이유를 남깁니다.
- 테스트 코드에서는 `#require(...)` 또는 `XCTUnwrap(_:)`을 씁니다.

## 하드코딩

- 리터럴 문자열·숫자·URL·키를 코드에 직접 두지 않습니다.
- 문자열은 `String(localized:)`, 설정값은 주입, 상수는 `enum` 네임스페이스에 모읍니다.
- 크기·간격 같은 UI 수치는 파일 하단의 `private enum Layout`에 모읍니다.

## 동시성

- Swift 6 언어 모드 기준으로 작성합니다. 데이터 레이스 진단을 억제하지 않습니다.
- `@unchecked Sendable`은 쓰지 않습니다. 불가피하면 이유를 주석으로 남기고 계획 문서에 기록합니다.
- UI를 다루는 타입은 `@MainActor`로 격리합니다.

## 에러 처리

- 도메인별 `Error` 타입을 정의하고, `catch`에서 삼키지 않습니다.
- 무시해도 되는 에러는 왜 무시해도 되는지 한 줄 주석을 답니다.

## 의존성

- 구체 타입이 아니라 프로토콜에 의존하고, 생성자로 주입합니다.
- 싱글턴(`.shared`)을 새로 만들지 않습니다.

## 린트 억제

- 파일·블록 단위 억제(`swiftlint:disable <규칙>`)는 금지입니다. 커스텀 규칙이 error로 막습니다.
- 불가피한 한 줄은 `swiftlint:disable:next <규칙>`으로 범위를 좁히고, 바로 위에 이유를 남깁니다.
- 규칙 자체가 이 프로젝트에 안 맞는다면 억제가 아니라 `.swiftlint.yml`을 고치는 게 맞습니다.

## 스타일

- `swiftformat` 결과가 정답입니다. 포맷을 두고 논쟁하지 않습니다.
- 접근 수준은 가능한 좁게(`private` → `internal` 순으로 올립니다).
- 타입당 한 파일, 파일명은 타입명과 일치시킵니다.
