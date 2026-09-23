# 리뷰 결정 기록: feat/tracking-featureflags

계획: `docs/plans/2026-09-23-tracking-featureflags-dependency-rules.md`. 계획의 "결정 사항" 표도 확정 결정으로 본다.

## 확정 결정

| ID | 결정 | 이유 |
|---|---|---|
| D1 | 피처의 `{name}Testing`은 `(.featureInterface(name), Testing)`으로 해석한다 | Testing 타깃은 Interface의 목이고 Interface에만 의존한다. 그래야 다른 피처의 테스트·데모가 쓸 수 있다(구현 중 사용자 결정) |
| D2 | 의존 규칙 위반은 `fatalError`로 멈추고, 문구가 보이지 않는 점은 주석·문서로 안내한다 | Tuist 4.208.0이 매니페스트 stderr를 버린다. 문구는 오류에 찍힌 `xcrun swift ... --tuist-dump`를 직접 실행하면 보인다(구현 중 사용자 결정) |
| D3 | 브랜치는 origin/main(`be7f2e0`, `case core(String)`과 `new-module.sh` 포함) 위에 둔다. `Module`에는 이름 있는 `.tracking`/`.featureFlags`와 `.core(String)`이 함께 있다 | 리뷰(R1-1, R1-5)가 rebase 결과를 기준으로 했다. 충돌은 두 쪽을 모두 살려 풀었다 |
| D4 | `.core(String)` 모듈의 의존은 양방향 모두 `mayDepend`에 규칙을 직접 더한다. 다른 모듈이 의존하면 `(.feature, .core("<Name>"))`, 이 모듈이 의존하면(테스트·데모의 `.testing(_:)` 포함) `(.core("<Name>"), .domain)` 같은 규칙이다. `new-module.sh` core 안내, `case core` 주석, `README.md` "직접 하는 일"에 둘 다 적는다(README는 R3-1에서 추가). App은 규칙 없이 의존할 수 있다 | 규칙 없는 의존은 generate가 문구 없이 멈추므로(D2) 만드는 시점에 알려야 한다(R1-1, R2-1에서 반대 방향 추가). 스크립트가 규칙을 자동으로 넣지는 않는다. 누가 의존할지, 무엇에 의존할지는 만드는 시점에 모른다 |
| D5 | 이름 있는 Core case로 올리는 기준: 여러 쌍에 걸친 규칙이 필요하거나 계층 역할을 문서 주석으로 밝혀야 할 때. 그 밖에는 `.core(String)`을 쓴다 | `.core` 주석("새 Core 모듈은 이 case로")과 `.tracking`/`.featureFlags`가 서로 다른 방향을 가리키는 것을 정리한다(R1-5) |
| D6 | Remote Config 받기 시작은 `makeFeatureFlagProvider(firebaseDecision:startFetch:)`의 `switch` 안에서 제공자 선택과 함께 정한다 | 판정을 한 곳에 두어 `Decision`에 case가 늘면 컴파일러가 알린다. 클로저 주입으로 `.configure`에서만 한 번 부르는 것을 테스트한다(R1-2) |
| D7 | `FeatureFlag`의 같음과 해시는 `key`만 본다 | 원격 설정에서 플래그를 가리키는 것은 키뿐이다. 기본값이 다르게 적힌 같은 키가 `overrides`에서 무시되지 않게 한다(R1-3) |
| D8 | Remote Config 출처가 `.remote`/`.default`면 SDK `boolValue`를 그대로 쓴다. Bool로 읽히지 않는 문자열은 코드에서 막지 않고 README에서 콘솔 유형을 Boolean으로 두라고 안내한다 | SDK가 "Bool로 해석 불가"를 따로 알려 주지 않는다. 계획의 `resolve` 규칙(출처만 본다)을 유지한다(R1-4) |
| D9 | `LoggerEventTracker`는 `message(forName:)`과 `message(forParameters:)` 두 조각을 `track`과 테스트가 함께 쓴다. 이벤트 전체 문구 함수는 두지 않는다 | 두 조각의 privacy가 달라 따로 보간해야 한다. 테스트 전용 경로를 없애 `track`의 형식 변경이 테스트에 드러나게 한다(R1-6) |
| D10 | 문서와 스크립트의 core 모듈 예시 이름은 `Payments`다. `Analytics`, `RemoteConfig`처럼 App이 링크하는 Firebase 클래스 이름과 겹치는 이름은 예시로 쓰지 않는다 | 예시를 그대로 따라 만든 모듈을 App에 연결하면 계획의 "알려진 함정"(이름 충돌)에 걸린다(R2-2) |

## 라운드 이력

### 1라운드

- 리뷰 기준 스냅샷: `60eef7be22de90c60f552c7648684fec3f340674`
- 선행 작업: origin/main으로 fast-forward하고 작업 트리 변경을 다시 적용했다. `Module.swift` 충돌은 두 쪽을 모두 살렸다(D3). 기존 매니페스트 generate, 빌드, 임시 위반(Home→Data, Home→Testing, Interface→DesignSystem) 중단을 다시 확인했다. scaffold 템플릿(`Tuist/Templates/*/Project.stencil`)의 기본 의존은 모두 규칙을 통과한다.
- R1-1 반영: `Scripts/new-module.sh` core 안내에 `mayDepend` 규칙 추가 안내 3줄, `case core` 주석에 같은 내용(D4). 안내 예시 `(.feature, .core("Payments"))`를 임시로 넣어 generate가 통과하는 것을 확인하고 되돌렸다.
- R1-2 반영: `startFetch` 클로저 주입(D6). `.configure`에서 한 번, 건너뛰면 0번 부르는 테스트를 더했다.
- R1-3 반영(Consider, 사용자 요청): `FeatureFlag` `==`/`hash`를 `key`만으로(D7). `StubFeatureFlagProviderTests` 추가.
- R1-4 반영(Consider, 사용자 요청): FeatureFlags README에 콘솔 유형 Boolean 안내(D8). 코드 변경 없음.
- R1-5 반영(Consider, 사용자 요청): `case core` 주석에 이름 있는 case로 올리는 기준(D5).
- R1-6 반영(Consider, 사용자 요청): 문구 조각 두 개로 나누고 테스트를 조각 기준으로 바꿨다(D9).
- 검증: 전체 `xcbuild.sh test`, `build -configuration Release` 통과.

### 2라운드

- 리뷰 기준 스냅샷: `2ef82c1095dc28fe35330885361dd4172d027530`
- R2-1 반영: `new-module.sh` core 안내와 `case core` 주석에 반대 방향 규칙(`(.core("<Name>"), .domain)`)을 더했다(D4 확장, 번복 아님). 예시 규칙을 `mayDepend`에 임시로 넣어 generate가 통과하는 것을 확인하고 되돌렸다.
- R2-2 반영(Consider, 사용자 요청): `README.md`의 예시 두 곳과 `new-module.sh` 헤더 주석 예시를 `Analytics`에서 `Payments`로 바꿨다(D10). 헤더 주석은 리뷰가 짚지 않았지만 같은 예시라 함께 고쳤다.
- 검증: generate와 전체 `xcbuild.sh test` 통과. 이번 변경은 주석·스크립트 안내·README뿐이라 Release 빌드는 다시 돌리지 않았다.

### 3라운드

- 리뷰 기준 스냅샷: `b2a19a9fe5559be5a94708d33aa76eb43c2641e0`
- Blocker·Should fix 없음. R2-1(D4), R2-2(D10) 반영이 확인됐다.
- R3-1 반영(Consider, 사용자 요청): `README.md` "직접 하는 일"에 `mayDepend(on:)` 양방향 규칙 추가 안내를 더했다. D4의 안내 위치에 README를 더한 것이고 결정 내용은 그대로다.
- 검증: 문서만 바뀌어 빌드·테스트는 다시 돌리지 않았다.
