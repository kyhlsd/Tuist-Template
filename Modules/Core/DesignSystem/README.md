# DesignSystem

SwiftUI 디자인 시스템. 색·폰트·여백을 토큰으로 관리하고 그 위에 컴포넌트를 쌓는다.

**iOS 17.0+ / Xcode 27+ / Swift 6 (MainActor 기본 격리)**

- 사용 예시 모음: [CHEATSHEET.md](docs/CHEATSHEET.md)
- 문제 해결: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 특징

- **토큰 기반 테마**: 색·폰트·여백·반경·그림자·애니메이션 시간을 `Theme` 하나로 묶어 환경값으로 주입한다. 인스턴스를 바꾸는 것만으로 브랜드 색, 커스텀 폰트, 화이트라벨을 지원한다.
- **라이트·다크 자동 대응**: 색 토큰은 동적 색이라 인터페이스 스타일에 따라 저절로 바뀐다. 강조색 위 글자색(`onAccent`)도 모드마다 뒤집힌다.
- **접근성이 기본값**: Dynamic Type 확대, 44pt 터치 영역, VoiceOver 라벨·안내, 모션 감소 설정을 컴포넌트가 알아서 처리한다. 모든 색 조합의 WCAG AA 대비율은 테스트가 지킨다.
- **실수를 막는 컴포넌트**
  - `AsyncButton`: 작업이 끝날 때까지 탭을 받지 않아 이중 요청을 막는다.
  - `AppIconButton`: 접근성 라벨이 필수 파라미터다.
  - `.appFittedSheet`: 콘텐츠 높이에 맞춰 열린다.
  - 토스트 큐: 연달아 뜨는 알림을 순서대로 보여 준다.
- **주입 가능한 햅틱**: 전역 엔진 없이 환경값 `\.hapticPlayer`로 주입한다. 앱 설정에서 끄거나 테스트에서 교체하기 쉽다.
- **모듈 문구 지역화**: 컴포넌트가 직접 쓰는 문구는 이 모듈의 문자열 카탈로그에서 가져온다.
- **카탈로그 앱**: 모든 토큰과 컴포넌트를 시뮬레이터나 기기에서 직접 만져 본다.
- **회귀 테스트**: 토큰 대비율·스케일 테스트, 컴포넌트 스냅샷 테스트, 핵심 로직 단위 테스트가 들어 있다.

---

## 시작하기

### 1. 의존성 추가

다른 모듈의 `Project.swift`에 `.module(.designSystem)`을 추가하고 `import DesignSystem`한다.

### 2. 테마 주입 (앱 진입점에서 한 번)

```swift
import DesignSystem

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().theme(.standard)
        }
    }
}
```

### 3. 화면 작성

```swift
struct ProfileView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.lg) {
                Text("프로필")
                    .appText(\.titleLarge, color: \.textPrimary)

                VStack(alignment: .leading, spacing: theme.metrics.spacing.sm) {
                    Text("이름").appText(\.bodySmall, color: \.textSecondary)
                    Text("김학도").appText(\.bodyLarge, color: \.textPrimary)
                }
                .appCard()

                AsyncButton("저장") { await viewModel.save() }
                    .buttonStyle(.appPrimary)
            }
            .appReadableWidth()
            .appScreenPadding()
        }
        .appScreenBackground()
    }
}
```

토큰은 두 가지 방식으로 쓴다.

```swift
// 색·폰트·아이콘 → KeyPath로 넘긴다
.appText(\.bodyLarge, color: \.textPrimary)

// 레이아웃 수치 → 직접 읽는다 (SwiftUI 기본 API에 넘겨야 하므로)
VStack(spacing: theme.metrics.spacing.md)
```

### 4. 카탈로그로 확인

`DesignSystem` 스킴을 실행(⌘R)하면 카탈로그 앱(`DesignSystemDemo`)이 뜬다. 햅틱, 시트, 포커스처럼 프리뷰로 확인하기 어려운 동작도 여기서 본다.

- 코드는 `Demo/Sources/Catalog/`에 있고 페이지마다 파일 하나(`Catalog/Pages/`)다. 각 파일에 라이트·다크·접근성 확대 프리뷰가 들어 있다.
- 카탈로그는 public API만 쓴다. 여기서 컴파일되지 않는 컴포넌트는 다른 모듈에서도 쓸 수 없다.
- 앱 본체는 데모 타깃에 의존하지 않으므로 릴리스 빌드에 포함되지 않는다.

---

## 모듈 구성

Tuist 코어 모듈이다. 설정은 [Project.swift](Project.swift) 한 곳에 있다.

| 항목 | 내용 |
|---|---|
| 타깃 | `DesignSystem`(정적 프레임워크) · `DesignSystemTests` · `DesignSystemDemo`(카탈로그 앱) |
| 동시성 | `isMainActorByDefault: true`. 모듈 전체가 메인 액터에 격리된다 |
| 리소스 | `Resources/`: 에셋 카탈로그, 문자열 카탈로그(`Localizable.xcstrings`). 코드에서는 `Bundle.module` |
| 스냅샷 | `hasSnapshotTests: true`. 기준 이미지를 테스트 번들에 넣는다(아래 "테스트" 참고) |
| 린트 | `Sources/Tokens/.swiftlint.yml`이 토큰 폴더에서만 `no_magic_numbers`를 끈다. 토큰은 숫자를 정의하는 곳이다 |

```
Sources/
├── Tokens/         Theme, 색·폰트·메트릭 토큰
├── Styles/         ButtonStyle·ToggleStyle 등 스타일
├── Modifiers/      .app… 모디파이어, AppIconButton
├── Views/          직접 만드는 뷰 (AsyncButton, AppTextField, …)
├── Overlays/       토스트·배너·시트·다이얼로그
├── Feedback/       햅틱
├── Diagnostics/    대비율 계산, 프리뷰 헬퍼
└── Localization/   DesignSystemStrings
```

---

## 토큰

### 색

```swift
.appText(\.bodyLarge, color: \.textPrimary)   // 폰트 + 색
.appForeground(\.accent)                       // 색만
theme.colors.surface                           // 직접
```

| 그룹 | 토큰 |
|---|---|
| 표면 | `background` `backgroundElevated` `surface` `surfacePressed` `surfaceMuted` |
| 텍스트 | `textPrimary` `textSecondary` `textTertiary` `textDisabled` |
| 선 | `border` `borderStrong` `separator` |
| 강조 | `accent` `accentPressed` `accentDisabled` `accentSubtle` `onAccent` |
| 상태 | `success` `warning` `danger` `info` (+ 각 `~Subtle`) |
| 기타 | `overlay` `controlKnob` |

- 상태 색은 `success` / `successSubtle`처럼 짝으로 쓴다. 앞쪽이 콘텐츠, 뒤쪽이 배경이며 모든 조합이 WCAG AA를 만족한다.
- `onAccent`는 강조색 **위**에 놓이는 색이다. 라이트에서는 흰 글자, 다크에서는 어두운 글자로 바뀐다.

### 폰트

```swift
Text("제목").appText(\.titleMedium)
```

`display` 32 · `titleLarge` 26 · `titleMedium` 20 · `titleSmall` 17 · `bodyLarge` 17 · `bodyMedium` 15 · `bodySmall` 13 · `label` 15 · `caption` 12

모두 Dynamic Type에 맞춰 커진다.

### 메트릭

```swift
theme.metrics.spacing.md
theme.metrics.radius.lg
theme.metrics.icon.md
```

| 종류 | 값 |
|---|---|
| `spacing` | `xxs` 2 · `xs` 4 · `sm` 8 · `md` 12 · `lg` 16 · `xl` 24 · `xxl` 32 · `xxxl` 48 |
| `radius` | `xs` 4 · `sm` 8 · `md` 12 · `lg` 16 · `xl` 24 · `full` |
| `icon` | `xs` 12 · `sm` 16 · `md` 20 · `lg` 24 · `xl` 32 |
| `border` | `hairline` · `regular` 1 · `thick` 2 · `focus` 3 |
| `shadow` | `card` · `floating` · `modal` |
| `duration` | `instant` 0.1 · `fast` 0.18 · `normal` 0.28 · `slow` 0.45 |
| 기타 | `minimumHitTarget` 44 · `contentMaxWidth` 680 · `formMaxWidth` 480 |

### 커스텀 테마

```swift
var colors = ColorTokens.standard
colors.accent = Color(light: .init(rgb: 0xE85D2A), dark: .init(rgb: 0xFF8A5C))

let theme = Theme(colors: colors, typography: .standard, metrics: .standard)
ContentView().theme(theme)
```

커스텀 폰트는 provider만 바꾼다.

```swift
var typography = TypographyTokens.standard
typography.provider = CustomFontProvider { weight in
    weight >= .semibold ? "Pretendard-SemiBold" : "Pretendard-Regular"
}
```

팔레트를 바꾼 뒤에는 토큰 테스트를 돌려 대비율 미달이 없는지 확인한다.

---

## 컴포넌트

| 분류 | 항목 |
|---|---|
| 버튼 | `.appPrimary` `.appSecondary` `.appTextButton` `AsyncButton` `AppIconButton` `.appPressable` |
| 입력 | `AppTextField` `AppSearchField` `.appSwitch` `.appCheckbox` |
| 표시 | `AppBadge` `AppChip` `AppListRow` `AppSectionHeader` `AppDivider` `.appLinear` |
| 상태 | `AppStatusView` `AppLoadingView` `AppSkeleton` `.appLoadingOverlay` |
| 오버레이 | `.appToast` `AppToastQueue` `AppBanner` `.appStatusBanner` `.appSheet` `.appFittedSheet` `.appDialog` `.appErrorAlert` |
| 레이아웃 | `.appCard` `.appScreenPadding` `.appScreenBackground` `.appReadableWidth` `.appShadow` |
| 접근성 | `.appFocusRing` `.appMinimumHitTarget` `.appAccessibilityElement` `AppAdaptiveStack` `AppAccessibility` |
| 햅틱 | `\.hapticPlayer` `.hapticPlayer(_:)` `.appHaptic(_:trigger:)` |
| 진단 | `ColorContrast` `.appPreview()` `AppPreviewVariants` `AppContrastInspector` |

각 항목의 사용 예시는 [CHEATSHEET.md](docs/CHEATSHEET.md)에 있다.

### 알아 둘 동작

- **`AsyncButton`**: 버튼이 화면에서 사라지면 작업에 취소를 요청한다. 작업이 실제로 끝날 때까지는 다시 나타나도 진행 중으로 표시되고 탭을 받지 않는다. 이 잠금은 같은 화면 인스턴스 안에서만 유지된다. 화면을 벗어나도 끝까지 완료돼야 하거나 중복을 반드시 막아야 하는 작업은 ViewModel이 실행한다.
- **햅틱**: `AsyncButton`, `.appPressable`, `AppIconButton`에 기본으로 물려 있고 `haptic: nil`로 끈다. 앱 전체에서 끄려면 루트에 `.hapticPlayer(nil)`을 주입한다.
- **`.appFittedSheet`**: 콘텐츠 높이만큼 열리고, 화면보다 길면 최대 높이에서 스크롤된다. 텍스트 입력이 있는 시트는 `.appSheet`에 `.large`를 함께 쓴다.
- **`ColorContrast`**: 반투명 전경은 배경과 합성해 계산한다. 반투명 배경은 판정할 수 없으므로 `nil` 또는 "판정 불가"로 돌려준다.

---

## 테스트

```
Tests/
├── DesignTokenTests.swift         대비율 · 아이콘 · 토큰 스케일
├── ComponentSnapshotTests.swift   컴포넌트 외형 회귀
├── SnapshotSupport.swift          스냅샷 렌더링·비교
├── AsyncTaskRunnerTests.swift     AsyncButton 실행 상태
├── FittedSheetDetentTests.swift   콘텐츠 높이 시트 detent
├── HapticPlayingTests.swift       햅틱 주입·재생 판단
├── AppToastQueueTests.swift       토스트 큐 순서
└── __Snapshots__/                 스냅샷 기준 이미지 (커밋한다)
```

```bash
./.claude/scripts/xcbuild.sh test -only-testing:DesignSystemTests
```

### 스냅샷 테스트

시뮬레이터에서만 돈다. 기종은 하나로 고정한다(렌더링 결과가 기종마다 다르다).

**새 컴포넌트의 기준 이미지 만들기**

1. `SnapshotSupport.swift`에서 `static var isRecording = true`로 바꾸고 테스트를 한 번 실행한다. 기준 이미지가 `Tests/__Snapshots__/`에 생긴다.
2. 이미지를 눈으로 확인한 뒤 `isRecording = false`로 되돌린다. 켜 둔 채로 두면 외형이 바뀌어도 항상 통과한다.
3. `tuist generate`를 실행한다. 기준 이미지는 테스트 번들에서 읽으므로, 새 파일은 프로젝트를 다시 생성해야 번들에 들어간다.

**기존 기준 이미지 갱신**: 파일을 지우고 위 과정을 반복하거나 새 이미지로 덮어쓴다. 파일 추가가 아니므로 빌드만 하면 된다.

**경로**

- 기준 이미지는 테스트 번들에서 읽으므로 저장소 위치(`~/Desktop` 등)와 상관없이 동작한다.
- 새 기준 이미지와 실패 결과(`__Failures__/`, git 제외)는 소스 옆 `__Snapshots__/`에 쓴다.
- 소스 폴더에 쓸 수 없는 환경(CI 등)에서는 `SNAPSHOT_DIR`로 읽기·쓰기 경로를 함께 바꾼다. xcodebuild에는 `TEST_RUNNER_SNAPSHOT_DIR`로 넘긴다.

다른 모듈에서 스냅샷 테스트를 쓰려면 그 모듈의 `Project.swift`에 `hasSnapshotTests: true`를 켜고 `SnapshotSupport.swift`를 가져간다.

---

## 문구와 지역화

컴포넌트가 직접 화면에 쓰는 문구("다시 시도", "닫기" 등)는 모두 `Localization/DesignSystemStrings.swift`에서 가져온다.

- `Text("확인")`처럼 리터럴을 쓰면 SwiftUI는 **앱의 메인 번들**에서 번역을 찾는다. 이 모듈의 문자열 카탈로그를 보려면 `String(localized:bundle: .module)`이어야 하고, 그 호출을 `DesignSystemStrings` 한 곳에 모았다.
- 공개 API의 기본 인자는 internal 심볼을 참조할 수 없다. 그래서 기본 문구가 있는 파라미터는 `String? = nil`로 받고 내부에서 채운다(`AppDialog(confirmTitle:)`, `AppStatusView.error(title:)`, `AppAlertError(title:)`).
- 호출하는 쪽이 넘기는 문구(제목, 메시지)는 호출하는 모듈이 지역화한다.

---

## 새 컴포넌트를 만들 때

**위치**

| 만드는 것 | 폴더 |
|---|---|
| 값 정의 | `Tokens/` |
| `ButtonStyle` 등 프로토콜 준수 | `Styles/` |
| `.someModifier()` 형태 | `Modifiers/` |
| 직접 인스턴스화하는 View | `Views/` |
| 화면 위에 뜨는 것 | `Overlays/` |
| 특정 화면에서만 쓰는 뷰 | **여기 아님**. Feature 모듈에 둔다 |

**체크리스트**

- 매직 넘버·리터럴 색 대신 토큰을 쓴다
- 컴포넌트 고유 치수는 파일 안 `private enum Layout`에 모은다(제네릭 타입이면 파일 전용 enum으로 밖에 둔다)
- 상태 불투명도(비활성·눌림)는 `StateOpacity`
- 높이는 `frame(height:)`가 아니라 `frame(minHeight:)`. 글자가 커지면 늘어나야 한다
- 터치 대상은 44pt 이상. 아이콘만 있는 버튼은 `AppIconButton`
- 아이콘만 있는 컨트롤에는 접근성 라벨을, 텍스트 옆 장식 아이콘에는 `accessibilityHidden(true)`
- 아이콘은 `AppIcon`으로. `Image(systemName:)` 문자열을 쓰지 않는다
- 화면 문구는 `DesignSystemStrings`로(리터럴 금지)
- 공개 타입이면 init도 `public`. 카탈로그(Demo)에서 컴파일되는지로 확인한다
- 색만으로 의미를 전달하지 않는다
- 햅틱은 `@Environment(\.hapticPlayer)`로 받아 `playIfEnabled`로 재생한다
- 라이트·다크·접근성 XXL 프리뷰를 확인한다
- 카탈로그에 섹션을 추가하고, 외형이 중요한 컴포넌트는 스냅샷 테스트를 추가한다

**스타일 프로토콜을 만든다면** 중첩 타입 이름을 `Body`로 짓지 말고, `@Environment`는 별도 `View`에 둔다. 이유는 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)에 있다.
