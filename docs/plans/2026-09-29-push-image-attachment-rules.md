# 알림 이미지 첨부 판정 로직을 Push 모듈로 옮겨 테스트한다

## 목표

- `ImageAttachmentLoader`의 판정 로직 두 가지를 `Push` 모듈의 순수 함수로 옮긴다.
  - 2xx 응답만 받는 판정
  - 첨부 파일의 경로·확장자를 정하는 규칙
- 두 함수를 `PushTests`에서 네트워크·디스크 없이 테스트한다.
- 익스텐션의 `ImageAttachmentLoader`는 Push 함수를 불러 다운로드·파일 이동·`UNNotificationAttachment` 생성만 한다.
  동작은 지금과 같다.
- `Modules/Core/Persistence/README.md` 주의 문단에 한 줄을 더한다.
  "백그라운드 실행 경로를 추가하면 이 판단을 다시 검토한다"는 조건이다.
- 헤더·URL 어디에도 확장자가 없을 때 `Content-Type`(MIME 타입)으로 확장자를 정한다(4단계, 구현 중 추가).
- `./.claude/scripts/xcbuild.sh test` 전체가 통과하고, `xcbuild.sh build`가 통과한다.
  빌드는 익스텐션을 포함한 앱 전체를 빌드한다.

## 범위 밖

- 첨부 동작 바꾸기. 4단계의 MIME 타입 확장자 추론만 예외다.
  - 예: 제한 시간 변경, `serviceExtensionTimeWillExpire` 추가
  - 1-3단계는 지금 동작을 그대로 옮기고 테스트로 고정만 한다.
  - 테스트를 쓰다가 기존 동작의 결함이 보이면 고치지 말고 "위험 요소"에 적은 뒤 사용자에게 알린다.
- 익스텐션 테스트 타깃 추가.
- `AuthSession`이 첫 상태를 판단하는 방식(persistence D3) 변경. 이번에는 문서 한 줄만 더한다.
- `docs/plans/2026-09-28-staging-usecase-extensions.md` 수정.
  - 이 작업이 끝나면 그 문서의 "검증할 로직은 모듈 테스트로 확인한다"가 사실이 되므로 고치지 않는다.

## 전제

- **작업 브랜치:** `main`에서 새 브랜치 `refactor/push-image-attachment-rules`를 만든다.
  `main`에 직접 커밋하면 훅이 막는다. `fix/review-home-cancel-retry-test`와는 서로 독립이다.
- **현재 코드:** `App/Extensions/NotificationService/Sources/ImageAttachmentLoader.swift`
  - 23-38줄 `attachment(from:)`
    - `session.download(from:)`로 받는다.
    - `(response as? HTTPURLResponse)?.statusCode`가 `200..<300`이 아니면 `LoadError.unexpectedResponse`를 던진다.
    - 확장자는 `response.suggestedFilename.map { ($0 as NSString).pathExtension } ?? url.pathExtension`이다.
    - 목적지는 `FileManager.default.temporaryDirectory/<UUID>.<확장자>`이다.
    - `moveItem` 한 뒤 `UNNotificationAttachment(identifier: "", url:)`를 만든다.
  - 40-42줄 `private enum Status`
  - 45-56줄 `URLSessionConfiguration.notificationAttachment`. 제한 시간 20초이고, 익스텐션에 남긴다.
- **Push 모듈 원칙:** [Modules/Core/Push/Project.swift](../../Modules/Core/Push/Project.swift) 주석에
  "Foundation 외에는 import 하지 않는다"가 있다. 이 작업은 이 원칙을 지킨다.
  `UNNotificationAttachment`는 익스텐션에 남는다.
- **기존 Push 코드:** `Modules/Core/Push/Sources/PushPayload.swift`
  - `public enum` 네임스페이스에 `public static func`를 두고, 상수는 `private enum`에 둔다. 새 파일도 같은 모양으로 쓴다.
- **테스트 스타일:** `Modules/Core/Push/Tests/PushPayloadTests.swift`
  - Swift Testing, `import Push`(`@testable` 아님), 한국어 `@Test` 설명, `동작_조건_기대결과` 이름을 쓴다.
- **응답 대역:** `HTTPURLResponse(url:statusCode:httpVersion:headerFields:)`로 만든다.
  네트워크 없이 `statusCode`와 `suggestedFilename`을 정할 수 있다.
  `Content-Disposition` 헤더를 넣으면 `suggestedFilename`이 바뀐다.
- **`suggestedFilename`이 헤더 없이 URL 마지막 경로에서 무엇을 돌려주는지:** 구현 중 확인.
  - 확장자가 없는 URL에 MIME 타입에 맞는 확장자를 붙이는지도 함께 확인한다.
  - 테스트는 관찰한 실제 동작을 고정한다.
- **새 파일을 추가하면 `tuist generate`가 필요하다.** `xcbuild.sh`는 generate를 돌리지 않는다.
- **README가 이 작업과 맞닿는 곳:** `README.md` 146줄
  "익스텐션 타깃에는 테스트 타깃이 없으므로, 검증할 로직도 모듈로 빼서 모듈 테스트로 확인한다(예: `PushPayloadTests`)".
  이 작업으로 이 문장이 사실이 된다.
- **Persistence README:** `Modules/Core/Persistence/README.md` 80-81줄에 Keychain 읽기 실패 때 캐시가 비는 주의가 있다.
  - 현재 앱에는 `UIBackgroundModes`·BGTask·silent push가 없어서 첫 잠금 해제 전에 실행될 경로가 없다.
  - 토큰은 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`로 저장된다(`KeychainTokenStore.swift:50`).
- 새 API는 쓰지 않는다. 최소 지원 버전(iOS 17) 대비 폴백도 필요 없다.

## 결정 사항

| 결정 | 선택 | 이유 |
| --- | --- | --- |
| 옮기는 범위 | 판정 로직(상태 코드, 파일 경로·확장자)만 순수 함수로 Push에 둔다. 다운로드·파일 이동·`UNNotificationAttachment` 생성은 익스텐션에 남긴다 | Push는 Foundation만 import 하는 원칙을 지킨다. 테스트 규약(네트워크·디스크 의존 금지)도 대역 없이 지킨다. 로더 전체를 옮기고 클로저를 주입하는 대안은 원칙 변경과 대역 두 개가 필요해 기각했다(사용자 결정) |
| 타입 모양 | `Push/Sources/PushImageAttachment.swift`에 `public enum PushImageAttachment`를 두고 정적 함수 두 개를 둔다 | `PushPayload`와 같은 네임스페이스 모양이고, 저장 상태가 없다 |
| 상태 코드 판정 | `static func isSuccessful(_ response: URLResponse) -> Bool`. `HTTPURLResponse`가 아니면 `false`다 | 지금 동작과 같다. 에러 타입(`LoadError`)은 익스텐션에 남겨 Push의 공개 표면을 작게 둔다 |
| 파일 경로 | `static func fileURL(for response: URLResponse, requestURL: URL, in directory: URL, name: String) -> URL` | 디렉터리와 이름을 인자로 받아야 테스트가 `FileManager`·`UUID` 없이 결과를 비교할 수 있다. 익스텐션은 `temporaryDirectory`와 `UUID().uuidString`을 넘긴다 |
| 동작 보존 | 확장자 규칙은 지금 식을 그대로 옮긴다 | 이번 작업은 테스트 공백을 메우는 것이다. 동작 변경은 범위 밖이다 |
| 확장자 없는 응답(4단계) | `Content-Disposition` 파일 이름 → 요청 URL → 응답 URL → MIME 타입 표 순서로 비어 있지 않은 첫 확장자를 쓴다. `suggestedFilename`은 `Content-Disposition` 헤더가 있을 때만 쓴다(CI 실패 후 수정: 헤더 없이 Foundation이 합성하는 값은 iOS 26에서 `Unknown`, iOS 27에서 MIME 확장자라 OS마다 결과가 달랐다. 사용자 결정). 표는 Push 안에 Foundation만으로 두고 `image/jpeg`·`image/png`·`image/gif`와 JPEG 비표준 별칭 `image/jpg`만 담는다(리뷰 R1-2). 셋 다 없으면 지금처럼 확장자 없이 둔다 | iOS는 헤더·URL 확장자가 없으면 `suggestedFilename`이 `Unknown`이라 확장자가 비고 첨부가 실패한다(1단계에서 관찰). UTType은 UniformTypeIdentifiers라 Push 원칙을 바꿔야 하고, 익스텐션에 두면 테스트할 수 없어 기각했다(사용자 결정). 표의 세 형식은 알림 첨부가 받는 이미지 형식이다 |
| Persistence README | 주의 문단에 "앱이 첫 잠금 해제 전에 실행될 수 있는 경로를 추가하면, 읽기 실패를 `.signedOut`과 구분하도록 다시 검토한다"를 더한다 | 템플릿 사용자가 백그라운드 push나 BGTask를 추가할 때 이 한계가 실제로 생긴다. 지금은 생기지 않으므로 코드는 바꾸지 않는다 |

## 변경 계획

### 1. Push에 판정 함수와 테스트를 추가한다

- **파일**
  - `Modules/Core/Push/Sources/PushImageAttachment.swift` (새 파일)
  - `Modules/Core/Push/Tests/PushImageAttachmentTests.swift` (새 파일)
- **변경**
  - `import Foundation`만 한다.
  - `isSuccessful(_:)`와 `fileURL(for:requestURL:in:name:)`를 구현한다.
  - 성공 범위 `200..<300`은 `private enum Status`에 둔다.
  - 문서 주석에 두 가지를 적는다.
    - 익스텐션이 쓰는 규칙이라는 점
    - 확장자를 붙이는 이유: 시스템이 확장자로 첨부 형식을 판단한다.
      지금 `ImageAttachmentLoader.swift:29` 주석을 옮긴다.
  - 파일을 추가한 뒤 `tuist generate`를 돌린다.
- **검증**
  - `./.claude/scripts/xcbuild.sh test -only-testing:PushTests`가 통과한다.
  - 각 테스트는 판정식을 잠시 바꿔 실패하는지 확인한다(뮤테이션 확인).

### 2. 익스텐션이 Push 함수를 쓰게 한다

- **파일:** `App/Extensions/NotificationService/Sources/ImageAttachmentLoader.swift`
- **변경**
  - 25-27줄의 판정을 `PushImageAttachment.isSuccessful(response)`로 바꾼다.
  - 30-33줄의 경로 계산을 `PushImageAttachment.fileURL(for:requestURL:in:name:)`로 바꾼다.
  - `private enum Status`를 지운다.
  - `import Push`를 더한다. 익스텐션은 이미 Push에 의존한다(`App/Project.swift:87`).
  - `LoadError`, 다운로드, `moveItem`, `UNNotificationAttachment` 생성, `URLSessionConfiguration` 확장은 그대로 둔다.
- **검증**
  - `./.claude/scripts/xcbuild.sh build`가 통과한다. 앱 빌드에 익스텐션이 포함된다.
  - 익스텐션 파일에 `200`, `pathExtension`, `appendingPathExtension`가 남지 않았는지 `grep`으로 확인한다.

### 3. 문서를 갱신한다

- **파일**
  - `Modules/Core/Push/Project.swift` 주석
  - `README.md` 50줄(모듈 설명)
  - `Modules/Core/Persistence/README.md` 80-81줄 뒤
- **변경**
  - Push 설명을 "푸시 payload 규약과 알림 첨부 판정. 앱과 알림 익스텐션이 함께 쓴다"로 바꾼다.
    Foundation만 쓴다는 문장은 유지한다.
  - `README.md` 146줄의 예시에 `PushImageAttachmentTests`를 더한다.
  - Persistence README에 결정 사항의 한 줄을 더한다.
- **검증**
  - 마지막으로 `./.claude/scripts/xcbuild.sh test` 전체를 한 번 돌린다.

### 4. 확장자가 없을 때 MIME 타입으로 정한다

- **파일**
  - `Modules/Core/Push/Sources/PushImageAttachment.swift`
  - `Modules/Core/Push/Tests/PushImageAttachmentTests.swift`
- **변경**
  - `fileURL`의 확장자 규칙을 결정 사항 순서로 바꾼다. MIME 표는 `private enum`에 둔다. `HTTPURLResponse.mimeType`은 Foundation이 소문자로 정규화하므로 따로 바꾸지 않는다(뮤테이션 확인에서 관찰).
  - 문서 주석에 순서를 적는다.
  - 익스텐션은 바꾸지 않는다.
- **검증**
  - `-only-testing:PushTests` 통과, 뮤테이션 확인, 전체 `xcbuild.sh test` 한 번.

## 테스트 전략

`PushImageAttachmentTests`(새 파일)에 다음을 둔다. 네트워크·디스크·시계를 쓰지 않는다.

| 테스트 | 검증하는 분기 |
| --- | --- |
| `isSuccessful_status200_returnsTrue` | 성공 범위 안 |
| `isSuccessful_status299_returnsTrue` | 범위 상한 경계 |
| `isSuccessful_status300_returnsFalse` | 범위 밖(리다이렉트는 받지 않음) |
| `isSuccessful_status404_returnsFalse` | 클라이언트 에러 |
| `isSuccessful_nonHTTPResponse_returnsFalse` | `HTTPURLResponse`가 아닌 응답 |
| `fileURL_contentDispositionFilename_usesItsExtension` | `suggestedFilename`이 헤더에서 온 경우. URL 확장자보다 우선한다 |
| `fileURL_contentDispositionWithoutExtension_usesRequestURLExtension` | 헤더 파일 이름에 확장자가 없으면 요청 URL로 |
| `fileURL_noHeader_prefersRequestURLExtension` | 헤더 없으면 합성된 `suggestedFilename` 대신 요청 URL이 응답 URL보다 우선 |
| `fileURL_extensionlessRequestURL_usesResponseURLExtension` | 요청 URL에 확장자가 없으면 응답 URL이 MIME보다 우선 |
| `fileURL_placesNameInDirectory` | 결과가 `directory/name.확장자`인지 |
| `fileURL_noExtensionAnywhere_…` | 헤더도 URL 확장자도 없을 때. 기대 결과는 구현 중 확인하고, 관찰한 동작을 고정한다 |

4단계에서 다음을 더한다.

| 테스트 | 검증하는 분기 |
| --- | --- |
| `fileURL_noExtensionWithImageMIMEType_usesMappedExtension` | jpeg·jpg·png·gif가 각각 jpg·jpg·png·gif로 |
| `fileURL_uppercaseMIMEType_usesMappedExtension` | 대문자 헤더도 찾는다(Foundation 정규화 고정) |
| `fileURL_redirectedToExtensionlessURL_usesRequestURLExtension` | 응답 URL에 확장자가 없으면(리다이렉트) 요청 URL 확장자가 MIME보다 우선. 응답 URL과 요청 URL을 다르게 둬야 이 분기를 탄다(리뷰 R1-1) |
| `fileURL_unmappedMIMEType_returnsNameWithoutExtension` | 표에 없는 타입은 지금처럼 확장자 없음 |

- 경계 네 개(200·299·300·404)는 `arguments:`를 쓴 매개변수 테스트 하나로 묶어도 된다.
- 수정이 필요한 기존 테스트는 없다.

## 위험 요소

| 위험 | 가능성 | 대응 |
| --- | --- | --- |
| `suggestedFilename`이 헤더 없는 경우 예상과 다른 값을 돌려준다(예: `Unknown`, MIME 기반 확장자) | 중 | 테스트로 실제 값을 관찰해 고정한다. 확장자가 비어 첨부가 실패하는 결함이 보이면 고치지 말고 사용자에게 알린다(범위 밖) |
| `tuist generate`를 빠뜨려 새 파일이 타깃에 들어가지 않는다 | 중 | 1단계에서 파일을 추가한 직후 generate를 돌린다. 테스트가 "Cannot find" 로 실패하면 이것부터 의심한다 |
| 실기기 푸시 첨부를 확인할 수 없다(APNs 키·서버 필요) | 높음 | 동작을 바꾸지 않는 리팩터이므로 빌드와 단위 테스트로 확인한다. 이전 계획과 같은 한계다 |

## 롤백

- 세 단계가 각각 커밋 하나다. 해당 커밋을 `git revert` 하면 된다.
- 1단계만 되돌리면 2단계가 빌드되지 않는다. 되돌릴 때는 2 → 1 순서로 되돌린다.
- 새 파일을 지운 뒤에는 `tuist generate`를 다시 돌린다.
