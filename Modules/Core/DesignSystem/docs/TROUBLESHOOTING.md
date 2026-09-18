# 트러블슈팅

이 디자인 시스템을 만들면서 실제로 막혔던 지점들. 대부분 SwiftUI 자체의 함정이라 다른 코드에서도 재현된다.

---

## 컴파일 에러

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

## 런타임 동작 이상

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

### 스냅샷 기준 이미지 저장 실패

실기기에서 실행 중일 가능성이 높다. 기준 이미지 경로는 Mac의 소스 경로라 기기에는 존재하지 않는다. 시뮬레이터로 전환한다.

### 대비율 테스트 실패

팔레트 수정 후 자주 발생한다. 특히 다크 모드의 옅은 배경 위 상태 색이 미달하기 쉽다.

강조색은 두 요구가 충돌한다 — 흰 글자가 보이려면 어두워야 하고, 어두운 배경과 구분되려면 밝아야 한다. **강조색을 밝게 유지하고 그 위 글자색을 뒤집는** 것이 정석이다. `onAccent`가 동적 색인 이유다.

수치는 카탈로그 Foundation 페이지의 Contrast 섹션이나 `AppContrastInspector` 프리뷰에서 확인한다.
