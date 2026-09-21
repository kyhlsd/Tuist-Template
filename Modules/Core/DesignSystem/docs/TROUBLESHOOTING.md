# 트러블슈팅

디자인 시스템을 쓰거나 확장할 때 만나기 쉬운 문제와 해결. 앞쪽은 이 모듈의 컴포넌트를 쓰다 생기는 문제,
뒤쪽은 컴포넌트를 만들 때 부딪히는 SwiftUI 자체의 함정이다.

---

## 컴포넌트 사용

### `AsyncButton`이 계속 진행 중으로 잠겨 있음

버튼이 화면에서 사라지면 작업에 취소를 요청하지만, 작업이 실제로 끝날 때까지는 탭을 받지 않는다(이중 요청 방지).
`action`이 취소를 확인하지 않고 오래 돌거나, resume되지 않는 continuation처럼 끝나지 않으면 버튼이 풀리지 않는다.
디버그 빌드에서는 취소 후 10초가 넘게 잠긴 채 탭이 거부되면 `AsyncButton` 카테고리로 경고 로그가 남는다.

**해결** — `action` 안에서 취소를 확인하거나(`Task.isCancelled`, `try Task.checkCancellation()`),
취소를 지원하는 API(`URLSession` 등)를 쓴다. 화면을 벗어나도 끝까지 돌아야 하는 작업은 ViewModel에서 실행한다.

### 같은 요청이 두 번 나감 (`AsyncButton`을 쓰는데도)

잠금은 같은 화면 인스턴스 안에서만 유지된다. pop 후 재진입, 조건 분기로 뷰가 다시 생성되는 경우에는
이전 작업이 아직 돌고 있어도 새 버튼이 탭을 받는다.

**해결** — 중복을 반드시 막아야 하는 작업은 ViewModel이 실행 상태를 가지고 버튼을 비활성화한다.

### 햅틱이 울리지 않음

- 시뮬레이터에서는 햅틱이 없다. 실기기에서 확인한다.
- 상위에서 `.hapticPlayer(nil)`이 주입돼 있지 않은지 본다(앱 설정의 햅틱 끄기).
- 컴포넌트에 `haptic: nil`이 넘어가 있지 않은지 본다.
- 직접 재생할 때는 `@Environment(\.hapticPlayer)`로 받은 값에 `playIfEnabled(_:)`를 호출한다.

### `appFittedSheet`의 높이가 맞지 않거나 입력창이 키보드에 가려짐

콘텐츠 높이만큼만 열리므로 키보드가 올라오면 공간이 부족하다.

**해결** — 텍스트 입력이 있는 시트는 `appSheet(isPresented:detents:)`에 `.large`를 함께 준다.
시트 안에서 `GeometryReader`로 화면 높이를 읽지 않는다(아래 "시트 안 `GeometryReader`" 참고).

### 대비 검사가 "판정 불가"로 나옴

배경색이 반투명하다. 반투명 배경은 아래에 무엇이 깔리느냐에 따라 대비가 달라지므로 판정하지 않는다.

**해결** — 실제로 보이는 불투명 배경(예: `overlay` 대신 그 아래의 `background`)으로 검사한다.
전경만 반투명한 경우는 배경과 합성해 정상 판정한다.

### 문구가 번역되지 않음

`Text("확인")`처럼 리터럴을 쓰면 SwiftUI는 앱의 메인 번들에서 번역을 찾는다.

**해결** — 이 모듈 안의 문구는 `DesignSystemStrings`를 거친다(`String(localized:bundle: .module)`).
호출하는 쪽이 넘기는 제목·메시지는 호출하는 모듈이 지역화한다.

---

## 컴포넌트를 만들 때: 컴파일 에러

### `struct body must be as accessible as its enclosing type`

`ButtonStyle` 안에 중첩 타입 이름을 `Body`로 지었을 때. Swift가 `associatedtype Body`의 witness로 그 타입을 추론해서, `private`이면 접근 수준이 어긋난다.

**해결** — 이름을 바꾼다 (`PrimaryButtonContent` 등). `ViewModifier`, `View`, `Layout`(`Cache`)에도 같은 함정이 있다.

### `Cannot convert 'String' to 'LocalizedStringKey'`

`LocalizedStringKey`는 문자열 **리터럴**만 암묵 변환된다. 변수는 안 된다.

**해결** — SwiftUI처럼 두 오버로드를 제공한다.

```swift
init(_ titleKey: LocalizedStringKey, icon: AppIcon)
init<S: StringProtocol>(_ title: S, icon: AppIcon)
```

### `Key path with root type '_' cannot be applied`

삼항 양쪽이 모두 키패스 리터럴이면 루트 타입을 추론할 문맥이 없다.

```swift
theme.colors[keyPath: cond ? \.success : \.danger]        // ✗
cond ? theme.colors.success : theme.colors.danger         // ✓
```

파라미터 타입이 확정된 자리는 문제없다: `.appText(\.body, color: cond ? \.a : \.b)`

### `Static stored properties not supported in generic types`

제네릭 타입은 타입 파라미터마다 저장소가 필요한데 런타임에 그 메커니즘이 없다.

**해결** — 제네릭 파라미터와 무관한 타입이면 파일 스코프로 꺼낸다.

### `Value of type 'AnyShapeStyle' has no member 'frame'`

`AnyShapeStyle`과 `Material`은 `ShapeStyle`이지 `View`가 아니다. `Color`만 양쪽을 다 만족한다.

**해결** — `Rectangle().fill(style)`로 감싼다.

### `failed to verify module interface`

타깃에 **Build Libraries for Distribution**이 켜져 있다. 로컬 모듈이라면 끄면 된다. 실제 원인은 이 메시지 **위쪽** 에러에 나온다.

---

## 컴포넌트를 만들 때: 런타임 동작 이상

### `ButtonStyle`에서 `@Environment`가 갱신되지 않음

스타일 프로토콜 타입은 `DynamicProperty`를 추적하지 않는다.

**해결** — 실제 그리기를 별도 `View`로 분리하고 거기서 `@Environment`를 선언한다.

### 배경색이 내비게이션 바까지 번짐

`background(_ style:)`의 `ignoresSafeAreaEdges` 기본값이 `.all`이다.

```swift
.background(color, ignoresSafeAreaEdges: [])   // 명시적으로 차단
```

오버로드에 따라 동작이 정반대다. `.background { Color.red }`(클로저)는 확장하지 않는다.

### `toolbarBackground`를 런타임에 토글할 수 없음

가시성만으로는 배경이 안 그려지고, 스타일을 지정하면 되돌릴 수 없다. 런타임 토글 용도가 아니다.

**해결** — 정적 설정으로 분기하거나 바 배경을 건드리지 않는 방식을 택한다.

### `offset`이 부모 경계를 넘어 그려짐

`offset`은 레이아웃 프레임을 바꾸지 않고 렌더링 위치만 옮긴다.

**해결** — `.clipShape(...)`를 함께 쓴다. 성능상 `offset` + `clipShape` 조합이 정석이다.

### 시트 안 `GeometryReader`가 화면 크기를 주지 않음

시트 안의 프록시는 화면이 아니라 **시트 자신의 크기**를 보고한다. 그 값으로 다시 detent를 계산하면 순환이 생겨 시트가 0으로 수렴한다.

**해결** — 화면 크기를 알 필요 자체를 없앤다. `.height(contentHeight)`를 요청하면 시스템이 최대치로 잘라준다.

같은 함정이 `ScrollView`, `List` 행, `overlay` 안에서도 생긴다.

### `safeAreaInset`으로 넣은 뷰가 내비게이션 바와 겹침

`safeAreaInset`은 프레임이 아니라 안전영역만 줄인다. `NavigationStack`의 바는 자기 프레임 최상단에 배치되므로 스택 **바깥**에서는 내려오지 않는다.

**해결** — 스택 바깥에서는 `VStack`으로 프레임 자체를 줄인다. `AppStatusBannerPlacement`가 이 차이를 감싼다.

### `confirmationDialog`가 엉뚱한 위치에 뜸

iPad·Mac에서는 **모디파이어가 붙은 뷰에 앵커된 팝오버**로 표시된다.

**해결** — 트리거 버튼에 붙이거나 `presentation: .alert`를 쓴다.

### `onChange` 마이그레이션에서 값이 한 프레임 늦음

| 버전 | 시그니처 | 전달 값 |
|---|---|---|
| iOS 14~16 | `{ newValue in }` | **새 값** |
| iOS 17+ | `{ oldValue, newValue in }` | 이전 값, 새 값 |

구버전 파라미터가 새 값이라, `{ newValue, _ in }`으로 바꾸면 이전 값을 쓰게 된다. 컴파일은 통과한다.

---

## 접근성

### VoiceOver가 버튼으로 인식하지 못함

`onTapGesture`는 접근성 트레잇을 자동으로 주지 않는다.

**해결** — `.appPressable { }` 또는 `AppIconButton`을 쓴다.

### 접근성 확대에서 가로 배치가 깨짐

`if` 분기로 `HStack`/`VStack`을 갈아끼우면 `_ConditionalContent`가 생겨 아이덴티티가 바뀌고 상태가 초기화된다.

**해결** — `AnyLayout`을 쓴다. `AppAdaptiveStack`이 이를 감싼다.

---

## 테스트

### 스냅샷: "기준 이미지가 없습니다"

기준 이미지는 테스트 번들에서 읽는다. 새 이미지를 기록했지만 번들에 아직 들어가지 않았거나, 기록한 적이 없다.

**해결** — 기록한 적이 없으면 `Snapshot.isRecording = true`로 한 번 실행해 만들고 다시 끈다. 그다음 `tuist generate`를
실행해 새 파일이 번들에 포함되게 한다. 모듈의 `Project.swift`에 `hasSnapshotTests: true`가 켜져 있는지도 확인한다.

### 스냅샷: "기준 이미지를 저장하지 못했습니다"

실기기에서 실행 중일 가능성이 높다. 기록 경로는 Mac의 소스 경로라 기기에는 존재하지 않는다.

**해결** — 시뮬레이터로 전환한다. 소스 폴더에 쓸 수 없는 환경(CI 등)이면 `SNAPSHOT_DIR`
(xcodebuild에는 `TEST_RUNNER_SNAPSHOT_DIR`)로 경로를 지정한다.

### 스냅샷: "외형이 달라졌습니다"

실제 결과가 `Tests/__Snapshots__/__Failures__/`에 저장된다. 기준 이미지와 눈으로 비교한다.

**해결** — 의도한 변경이면 기준 이미지를 지우고 다시 기록한다(파일을 교체한 경우는 빌드만 하면 된다).
의도하지 않았다면 회귀다. 시뮬레이터 기종이나 OS가 바뀌어도 렌더링이 달라질 수 있으니 기종을 하나로 고정한다.

### 대비율 테스트 실패

팔레트 수정 후 자주 발생한다. 특히 다크 모드의 옅은 배경 위 상태 색이 미달하기 쉽다.

강조색은 두 요구가 충돌한다 — 흰 글자가 보이려면 어두워야 하고, 어두운 배경과 구분되려면 밝아야 한다. **강조색을 밝게 유지하고 그 위 글자색을 뒤집는** 것이 정석이다. `onAccent`가 동적 색인 이유다.

수치는 카탈로그 Foundation 페이지의 Contrast 섹션이나 `AppContrastInspector` 프리뷰에서 확인한다.
새 조합을 검사 대상에 넣으려면 `ColorTokenContrastPairs`에 추가한다.
