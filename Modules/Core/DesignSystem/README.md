# DesignSystem

SwiftUI 디자인 시스템. 색·폰트·여백을 토큰으로 관리하고 그 위에 컴포넌트를 쌓는다.

**iOS 17.0+ / Xcode 27+ / Swift 6 (MainActor 기본 격리)**

---

## 시작하기

### 1. 테마 주입 (앱 진입점에서 한 번)

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

### 2. 화면 작성

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

                Button("저장") { }.buttonStyle(.appPrimary)
            }
            .appReadableWidth()
            .appScreenPadding()
        }
        .appScreenBackground()
    }
}
```

**두 가지 접근 방식**

```swift
// 색·폰트·아이콘 → KeyPath
.appText(\.bodyLarge, color: \.textPrimary)

// 레이아웃 수치 → 직접 읽기 (SwiftUI 기본 API에 넘겨야 하므로)
VStack(spacing: theme.metrics.spacing.md)
```

### 3. 카탈로그로 확인

카탈로그는 별도 앱 타깃 `DesignSystemDemo`(`Demo/Sources/`)에 있다. `DesignSystem` 스킴을 실행(⌘R)하면 이 앱이 떠서 시뮬레이터나 기기에서 전체 토큰과 컴포넌트를 직접 만져볼 수 있다. 햅틱, 시트, 포커스처럼 프리뷰로는 확인하기 어려운 동작도 여기서 본다.

카탈로그 코드는 `Demo/Sources/Catalog/`에 있고, 페이지마다 한 파일(`Catalog/Pages/`)이다. 각 파일에 라이트·다크·접근성 확대 프리뷰도 들어 있다. 데모 타깃은 앱 본체가 의존하지 않으므로 릴리스 빌드에 포함되지 않는다. 카탈로그는 `import DesignSystem`으로 public API만 쓰므로, 여기서 컴파일되지 않는 컴포넌트는 다른 모듈에서도 쓸 수 없다.

---

## 이 저장소에서의 구성

Tuist 코어 모듈이다. 설정은 [Project.swift](Project.swift) 한 곳에 있다.

| 항목 | 내용 |
|---|---|
| 타깃 | `DesignSystem`(정적 프레임워크) · `DesignSystemTests` · `DesignSystemDemo`(카탈로그 앱) |
| 동시성 | `isMainActorByDefault: true` — 모듈 전체가 메인 액터에 격리된다. 토큰의 `static let` 이 이 전제로 작성되어 있다 |
| 리소스 | `Resources/` — 에셋 카탈로그, 문자열 카탈로그(`Localizable.xcstrings`). 코드에서는 `Bundle.module` |
| 사용 | 다른 모듈의 `Project.swift` 에 `.module(.designSystem)` 을 추가하고 `import DesignSystem` |
| 린트 | `Sources/Tokens/.swiftlint.yml` 이 토큰 폴더에서만 `no_magic_numbers` 를 끈다(토큰은 숫자를 정의하는 곳이다) |

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

상태 색은 `success` / `successSubtle`처럼 짝으로 쓴다. 앞쪽이 콘텐츠, 뒤쪽이 배경이며 모든 조합이 WCAG AA를 만족한다.

`onAccent`는 강조색 **위**에 놓이는 색이다. 라이트는 흰 글자, 다크는 어두운 글자로 자동 전환된다.

### 폰트

```swift
Text("제목").appText(\.titleMedium)
```

`display` 32 · `titleLarge` 26 · `titleMedium` 20 · `titleSmall` 17 · `bodyLarge` 17 · `bodyMedium` 15 · `bodySmall` 13 · `label` 15 · `caption` 12

Dynamic Type에 맞춰 자동 확대된다.

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

커스텀 폰트는 provider만 교체한다.

```swift
var typography = TypographyTokens.standard
typography.provider = CustomFontProvider { weight in
    weight >= .semibold ? "Pretendard-SemiBold" : "Pretendard-Regular"
}
```

---

## 컴포넌트

전체 사용 예시는 [CHEATSHEET.md](docs/CHEATSHEET.md)를 참고한다.

| 분류 | 항목 |
|---|---|
| 버튼 | `.appPrimary` `.appSecondary` `.appTextButton` `AsyncButton` `AppIconButton` `.appPressable` |
| 입력 | `AppTextField` `AppSearchField` `.appSwitch` `.appCheckbox` |
| 표시 | `AppBadge` `AppChip` `AppListRow` `AppSectionHeader` `AppDivider` `.appLinear` |
| 상태 | `AppStatusView` `AppLoadingView` `AppSkeleton` `.appLoadingOverlay` |
| 오버레이 | `.appToast` `AppBanner` `.appStatusBanner` `.appSheet` `.appFittedSheet` `.appDialog` |
| 레이아웃 | `.appCard` `.appScreenPadding` `.appScreenBackground` `.appReadableWidth` `.appShadow` |
| 접근성 | `.appFocusRing` `.appMinimumHitTarget` `.appAccessibilityElement` `AppAdaptiveStack` |
| 햅틱 | `AppHaptic.success.trigger()` `.appHaptic(_:trigger:)` |

---

## 마이그레이션 메모

다른 브랜치를 머지하다 아래 심볼에서 컴파일 오류가 나면 이렇게 바꾼다.

| 이전 | 이후 |
|---|---|
| `ColorContrast.ratio(foreground:background:in:)` (`Double`) | `Double?`. 반투명 배경이면 `nil` |
| `ColorContrast.relativeLuminance(of:in:)` | 비공개. 대비 판정은 `ratio`, `meets`, `report`로 |
| `ColorContrast.Report.ratio` (`Double`) | `Double?`. 반투명 배경이면 `nil`. 표시에는 `formattedRatio` |

---

## 테스트

```
Tests/
├── DesignTokenTests.swift        대비율 · 아이콘 · 스케일
├── SnapshotSupport.swift
└── ComponentSnapshotTests.swift  컴포넌트 외형 회귀
```

**토큰 테스트**는 준비 없이 바로 실행된다. 팔레트를 바꾸면 대비율 미달을 잡아준다.

**스냅샷 테스트**는 시뮬레이터에서만 동작하며 최초 1회 기준 이미지 생성이 필요하다.

```swift
// SnapshotSupport.swift
static var isRecording = true   // 실행 → __Snapshots__/ 생성 → 확인 후 false로
```

`__Snapshots__/`는 커밋하고 `__Failures__/`는 `.gitignore`에 넣는다. 시뮬레이터 기종은 하나로 고정한다.

---

## 문구와 지역화

컴포넌트가 직접 화면에 쓰는 문구("다시 시도", "닫기" 등)는 모두 `Localization/DesignSystemStrings.swift` 에서 가져온다.

- `Text("확인")` 처럼 리터럴을 쓰면 SwiftUI 는 **앱의 메인 번들**에서 번역을 찾는다. 이 모듈의 문자열 카탈로그를 보려면 `String(localized:bundle: .module)` 이어야 하고, 그 호출을 `DesignSystemStrings` 한 곳에 모았다.
- 공개 API 의 기본 인자는 internal 심볼을 참조할 수 없다. 그래서 기본 문구가 있는 파라미터는 `String? = nil` 로 받고 내부에서 채운다. (`AppDialog(confirmTitle:)`, `AppStatusView.error(title:)`, `AppAlertError(title:)`)
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
| 특정 화면에서만 쓰는 뷰 | **여기 아님** — Feature 폴더 |

**체크리스트**

- 매직 넘버·리터럴 색 대신 토큰 사용
- 컴포넌트 고유 치수는 파일 내 `private enum Layout`에 (제네릭 타입이면 파일 전용 enum 으로 밖에)
- 상태 불투명도(비활성·눌림)는 `StateOpacity`
- 높이는 `frame(height:)` 가 아니라 `frame(minHeight:)` — 글자가 커지면 늘어나야 한다
- 터치 대상 44pt 이상. 아이콘만 있는 버튼은 `AppIconButton`
- 아이콘만 있는 컨트롤에 접근성 라벨, 텍스트 옆 장식 아이콘은 `accessibilityHidden(true)`
- 아이콘은 `AppIcon` 으로. `Image(systemName:)` 문자열을 쓰지 않는다
- 화면 문구는 `DesignSystemStrings` 로 (리터럴 금지)
- 공개 타입이면 init 도 `public` — 카탈로그(Demo)에서 컴파일되는지로 확인한다
- 색만으로 의미 전달하지 않기
- 라이트·다크·접근성 XXL 프리뷰 확인
- 카탈로그에 섹션 추가

**스타일 프로토콜을 만든다면** 중첩 타입 이름을 `Body`로 짓지 말고, `@Environment`는 별도 `View`에 두어야 한다. 자세한 이유는 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)에 있다.

---

## 문제가 생기면

[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 개발 중 마주친 SwiftUI 함정과 해결
