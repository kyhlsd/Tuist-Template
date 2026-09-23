# 리뷰 결정 기록: feat/module-scaffold-rename

계획: `docs/plans/2026-09-23-module-scaffold-rename.md`. 계획의 "결정 사항" 표도 확정 결정으로 본다.

## 확정 결정

| ID | 결정 | 이유 |
|---|---|---|
| D1 | `rename.sh`의 앱 이름은 `^[A-Za-z][A-Za-z0-9]*$`다(계획의 `_` 허용을 번복) | 앱 이름이 Swift 식별자(`@testable import`), 번들 ID(영숫자·`-`·`.`), URL 스킴(영문자로 시작, `_` 불가)에 모두 쓰인다. 셋의 교집합이다(R1-1, 사용자 확인) |
| D2 | `rename.sh`는 새 앱 이름이 기존 모듈 이름이나 그 파생 타깃(`<모듈>Interface/Testing/Tests/Demo`)과 대소문자 무시로 겹치면 멈춘다. 앱 테스트 타깃 `<이름>Tests`도 같이 본다 | 타깃 이름, 번들 ID(소문자), `@testable import`가 겹쳐 생성·빌드가 깨지고 원인이 치환 결과에 묻힌다(R1-2) |
| D3 | `new-module.sh`는 `Interface`/`Testing`/`Tests`/`Demo` 접미사와 시스템 모듈 이름(Swift, Foundation, SwiftUI, UIKit, Combine, Observation, Dispatch, SwiftData, CoreData, Charts, XCTest, Testing)을 거부한다. 접미사 검사만 대소문자를 구분하고, 나머지 이름 비교(시스템 모듈, 앱 타깃, 기존 모듈과 그 파생 타깃)는 대소문자를 무시한다 | 파생 타깃과 겹치거나 import 가 자기 모듈로 풀린다(R1-3). 시스템 모듈 목록은 흔히 import 하는 것만 둔다. 전부를 막는 것은 목표가 아니다. 대소문자 무시는 D2와 같은 이유다(R2-2). 접미사를 소문자로 비교하면 `Contests`, `Protesting` 같은 정상 이름이 막히므로, 대소문자만 다른 충돌(`Hometests`)은 새 모듈의 파생 이름과 기존 모듈의 파생 이름을 소문자로 직접 비교해 막는다(R3-1) |
| D8 | `rename.sh`도 D3의 시스템 모듈 목록으로 앱 이름을 거부한다. 목록은 두 스크립트에 따로 두고, 서로를 가리키는 주석을 단다 | 앱 이름도 앱 타깃의 Swift 모듈 이름이다(R2-1). 공용 파일을 `source`하는 안은 계획에 없는 파일이 늘고, 목록이 한 줄이라 주석으로 동기화해도 충분하다 |
| D9 | `new-module.sh`는 새 모듈과 그 파생 타깃이 앱 타깃(`<앱>`, `<앱>Tests`)과 대소문자 무시로 겹치면 멈춘다. `appName`을 읽지 못하면 멈춘다 | D2의 반대 방향이다(R2-4). 검사를 조용히 건너뛰지 않도록 `rename.sh`와 같이 처리한다(R2-3) |
| D4 | `new-module.sh`는 scaffold 직후 새 모듈 폴더에 `swiftformat`을 돌린다(계획 3단계 흐름에 추가) | SwiftFormat의 import 정렬이 모듈 이름에 따라 달라져(`Testing`과 `Tmp`의 순서) 템플릿만으로는 lint를 통과할 수 없다. 대상은 방금 만든 폴더뿐이다(R1-5) |
| D5 | `rename.sh`의 남은 이름 검사는 `git grep`의 종료 코드를 나눠 받는다. 1이면 통과, 2 이상이면 멈춘다 | git 오류를 "남은 것 없음"으로 읽지 않는다(R1-4) |
| D6 | 템플릿 테스트는 동어반복 자리표시 테스트로 두고, 지우라는 주석을 단다 | 계획상 목적은 테스트 타깃이 비지 않게 하는 것이다. 주석으로 생성된 테스트가 그대로 남는 것을 줄인다(R1-6) |
| D7 | 픽스처 파일은 `{{ name }}Route+Fixtures.swift`(core는 `{{ name }}Placeholder+Fixtures.swift`)다. 계획의 `{{ name }}Testing.swift`가 아니다 | `XTesting` 타입이 같은 이름의 모듈을 가리고, "파일명 = 타입명" 규칙을 지키기 위해 기존 `Item+Fixtures.swift` 형식을 따른다 |

## 라운드 이력

### 1라운드

- 리뷰 기준 스냅샷: `866f7d958a52a8b27fedb183dc7417bdb56c54d6`
- R1-1 반영: 앱 이름 정규식을 좁힘(D1). 계획의 확정 결정을 번복하므로 사용자 확인을 받았고, 계획 문서의 결정 표도 고쳤다.
- R1-2 반영: 모듈·파생 타깃과 이름 충돌 검사(D2). `Home`, `home`, `HomeDemo`, `DesignSystemTests`, `Domain`, `NetworkingInterface`가 exit 1이고 파일이 바뀌지 않는 것을 확인했다.
- R1-3 반영(Consider, 사용자 요청): 접미사·예약 이름 검사(D3). `core Testing`, `core SwiftUI`, `feature HomeInterface`, `core TuistApp`이 exit 1이다.
- R1-4 반영(Consider, 사용자 요청): `git grep` 종료 코드 구분(D5).
- R1-5 반영(Consider, 사용자 요청): 결정 기록에 D4로 남김. 코드 변경은 없다.
- R1-6 반영(Consider, 사용자 요청): 템플릿 테스트에 자리표시 주석(D6). 스캐폴드한 `Profile`/`Analytics`가 build와 테스트를 통과했다.

### 2라운드

- 리뷰 기준 스냅샷: `4d2c6c83c0a4915731b3e1576a135af03e2de787`
- R2-1 반영: `rename.sh`에 시스템 모듈 이름 검사를 추가했다(D8). 공용 파일 안은 택하지 않았다(D8 이유). `SwiftUI`, `swiftui`, `Testing`, `Charts`가 exit 1이다.
- R2-2 반영(Consider, 사용자 요청): `new-module.sh`의 이름 비교를 소문자로 통일했다(D3 수정). `core Tuistapp`, `feature Swiftui`가 exit 1이다.
- R2-3 반영(Consider, 사용자 요청): `appName`을 읽지 못하면 멈춘다(D9).
- R2-4 반영(Consider, 사용자 요청): 새 모듈의 파생 타깃과 앱 타깃의 충돌을 검사한다(D9). 현재 앱 이름(`TuistApp`)으로는 파생 타깃만 겹치는 입력을 만들 수 없어 로직만 검토했다. 정상 이름(`feature Shop --demo`)은 그대로 생성된다.

### 3라운드

- 리뷰 기준 스냅샷: `915ca7278273a4e1abbd0cf1d6a699d0420338ce`
- R3-1 반영(추천안): 접미사 검사는 그대로 두고, 기존 모듈의 파생 타깃과 소문자로 비교하는 검사를 더했다(D3 문구 수정). `Hometests`, `Homeinterface`, `Designsystem`, `Domaindemo`는 exit 1이다. `Contests`는 생성된다(확인 후 되돌림).

### 4라운드

- 리뷰 기준 스냅샷: `5fa6442e420165f55af93625a98eb60247e90d7a`
- R4-1 반영(Consider, 사용자 요청): 주석이 가리키는 대상을 "이름 끝의 Interface/Testing/Tests/Demo 검사"로 명시했다. 주석만 바뀌었다.
