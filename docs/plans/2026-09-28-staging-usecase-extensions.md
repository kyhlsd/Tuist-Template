# Staging 환경, 샘플 UseCase, 앱 익스텐션 헬퍼

구현 후 기록이다. 계획 단계를 거치지 않고 대화에서 방향을 정해 바로 구현했다.

## 목표

- Debug/Release 사이에 Staging 구성을 둔다. Release 최적화, 스테이징 서버, 번들 ID `.stg`, Firebase 는 구성별 plist.
- 뷰모델이 Repository 대신 UseCase 에 의존하는 샘플을 하나 둔다(`FetchItemsUseCase`).
- `Project.app(extensions:)` 로 앱 익스텐션을 붙이는 헬퍼를 두고, Notification Service Extension 샘플로 실제 사용한다.

## 범위 밖

- CD(아카이브·TestFlight 업로드). 도입 여부를 나중에 정한다.
- CI 에서 Staging 을 따로 빌드하는 잡. 컴파일 조건이 Release 와 같아 `release-build` 가 같은 컴파일 에러를 잡는다.
- 알림 권한 요청, 토큰 서버 전송. README 체크리스트에 남긴다.

## 결정 사항

### Staging
- 구성 이름은 `ConfigurationName.staging` 한 곳(`Settings+Common.swift`)에서 쓴다. 외부 패키지 구성은
  `Tuist/Package.swift` 의 `PackageSettings.baseSettings` 에 같은 이름·변형으로 적는다. 없으면 패키지가 기본 구성으로
  빌드되어 최적화·dSYM 설정이 앱과 어긋난다.
- `#if STAGING` 컴파일 조건을 만들지 않는다. 환경 차이는 xcconfig → Info.plist 값으로만 낸다.
- 앱 스킴 `TuistApp-Staging` 은 `Project.app` 이 만든다(실행·프로파일·아카이브·분석 모두 Staging, 테스트 없음).
- Firebase plist 는 번들 ID 마다 다르므로 `Configurations/Firebase/<구성>/` 에 두고 빌드 단계
  (`Scripts/firebase-copy-config.sh`)가 번들로 복사한다. 원본이 없으면 번들의 사본을 지운다(이전 빌드 사본이 남는 문제 방지).
  리소스 glob 으로 넣지 않은 이유: 같은 파일 이름이 여러 개 번들에 들어가 충돌한다.
- dSYM 업로드는 Staging 도 대상이다. plist 위치를 번들 사본으로 바꿨으므로 복사 스크립트가 먼저 돈다.

### UseCase
- 프로토콜 `FetchItemsUseCase`, 구현 `DefaultFetchItemsUseCase`(Domain), 스텁 `StubFetchItemsUseCase`(DomainTesting).
- 샘플 규칙은 빈 제목 제외 + `localizedStandardCompare` 정렬이다. 전달만 하는 UseCase 는 만들지 않는다는 기준을
  프로토콜 문서 주석과 README 에 적었다.

### 앱 익스텐션
- `AppExtension`(`.notificationService`, `.widget`)이 NSExtension 속성과 의존성을 갖고, `Project.app` 이 타깃 생성·앱 의존·
  의존 규칙 검사(`validateAppDependencies`)를 한다. 소스는 `App/Extensions/<Name>/Sources/`.
- 앱과 익스텐션이 공유하는 payload 규약을 위해 `App/Sources/Push/PushPayload.swift` 를 Core 모듈 `Push` 로 옮겼다
  (`Scripts/new-module.sh core Push`). 익스텐션에는 테스트 타깃을 두지 않고, 검증할 로직은 모듈 테스트로 확인한다.
- `image_url` 은 https 만 받는다. 서버가 보낸 값으로 로컬 파일·평문 요청을 유도하지 못하게 한다.

### Swift 6 격리 우회 (`nonisolated(unsafe)`)
- 위치: `App/Extensions/NotificationService/Sources/NotificationService.swift` 의 지역 상수 두 개(`deliver`, `content`).
- 이유: `UNNotificationServiceExtension.didReceive(_:withContentHandler:)` 의 핸들러와 `UNMutableNotificationContent` 가
  SDK(iOS 27)에서 `Sendable` 이 아니고, 핸들러 이름이 completion 형태가 아니라 async 변형도 생성되지 않는다
  (async 오버라이드는 "does not override" 로 실패했다). 다운로드를 `Task` 로 넘기려면 격리 검사를 끌 수밖에 없다.
- 안전 근거: 두 값은 `Task` 로 넘긴 뒤 원래 문맥에서 다시 쓰지 않고, `Task` 안에서도 한 번씩만 쓴다. 핸들러는 어느
  스레드에서 불러도 된다. `@unchecked Sendable` 래퍼 대신 지역 상수로 범위를 좁혔다.
- 걷어낼 조건: SDK 가 핸들러를 `@Sendable` 로 표시하거나 async 변형을 제공하면 제거한다.
- 핸들러를 저장해 `serviceExtensionTimeWillExpire` 에서 부르는 방식은 쓰지 않는다. 저장 상태가 생겨 우회가 더 넓어진다.
  대신 다운로드 타임아웃(20초)을 시스템 제한(약 30초)보다 짧게 둔다.

## 검증

- `./.claude/scripts/xcbuild.sh test`: 252개 통과(새 테스트: `DefaultFetchItemsUseCaseTests` 3개, `PushPayloadTests` 이미지 4개).
- `xcbuild.sh build`(Debug), `-configuration Staging`, `-configuration Release` 빌드 통과.
- Debug 앱 번들에 `PlugIns/NotificationService.appex` 가 들어가고 번들 ID `….dev.notificationservice`, 버전이 앱과 같음을 확인.
- `firebase-copy-config.sh` 를 임시 디렉터리에서 실행해 복사(원본 있음)와 삭제(원본 없음)를 확인.
- 실기기 푸시 수신과 이미지 첨부는 확인하지 않았다(APNs 키·서버 필요).

## 위험 요소

- `Tuist/Package.swift` 의 구성 목록과 `Settings+Common.swift` 가 어긋나면 generate 는 되지만 패키지가 다른 구성으로 빌드된다.
  README "환경" 절에 함께 고치라고 적었다.
- 익스텐션 번들 ID 는 앱 번들 ID 에 종속된다. 자동 서명이 아니면 구성마다(3개) 프로비저닝 프로파일이 따로 필요하다.
