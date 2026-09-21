# 치트시트

복사해서 바로 쓰는 사용 예시. `.theme(.standard)`이 상위에 주입되어 있다고 가정한다.

---

## 텍스트 · 아이콘

```swift
Text("제목").appText(\.titleLarge, color: \.textPrimary)
Text("본문").appText(\.bodyLarge)                    // 색 상속

Image(.settings).appIcon(\.md)
Image(.delete).appIcon(\.sm, weight: .semibold).appForeground(\.danger)

Label("설정", icon: .settings)                       // 리터럴 → 지역화 키
Label(page.title, icon: page.icon)                  // String 변수
```

새 아이콘은 `AppIcon` 열거형에 케이스를 추가한다.

---

## 버튼

```swift
Button("주요 액션") { }.buttonStyle(.appPrimary)
Button("보조 액션") { }.buttonStyle(.appSecondary)
Button("자세히") { }.buttonStyle(.appTextButton)
Button("삭제") { }.buttonStyle(.appTextButton(role: .destructive))

Button("작게") { }.buttonStyle(.appPrimary(size: .small, isFullWidth: false))
```

### 비동기 버튼

중복 탭 차단, 인디케이터 표시, 화면 이탈 시 취소가 내장되어 있다.

```swift
AsyncButton("저장하기") {
    try? await repository.save(item)
}
.buttonStyle(.appPrimary)

AsyncButton("동기화", icon: .refresh,
            progress: .besideLabel,
            progressTint: \.textPrimary) {      // 밝은 배경 스타일에서는 필수
    await viewModel.sync()
}
.buttonStyle(.appSecondary)
```

`progress`는 `.replacesLabel`(기본) / `.besideLabel` / `.none`.

> **주의:** 버튼이 화면에서 사라지면(`onDisappear`, 탭 전환 포함) 진행 중인 작업이 취소된다.
> 취소된 작업이 실제로 끝날 때까지는 다시 나타나도 진행 중으로 표시되고 탭을 받지 않는다(중복 요청 방지).
> 단, 이 잠금은 같은 화면 인스턴스 안에서만 유지된다. pop 후 재진입처럼 화면이 새로 만들어지면 다시 탭을 받는다.
> `action`에서 `Task.isCancelled`나 취소를 확인하는 API를 쓰면 더 빨리 풀린다.
> 화면을 벗어나도 끝까지 완료돼야 하는 저장은 ViewModel 등 화면보다 오래 사는 쪽에서 실행한다.

### 아이콘 버튼

```swift
AppIconButton(icon: .share, accessibilityLabel: "공유") { share() }
AppIconButton(icon: .delete, accessibilityLabel: "삭제", tint: \.danger) { delete() }
```

접근성 라벨이 필수 파라미터고 44pt 터치 영역이 강제된다.

### 누를 수 있는 영역

```swift
VStack { ... }
    .appCard()
    .appPressable { openDetail() }
```

---

## 입력

```swift
AppTextField(
    title: "이메일",
    placeholder: "name@example.com",
    text: $email,
    helperText: "로그인에 사용할 주소를 입력하세요.",
    keyboardType: .emailAddress,
    textContentType: .emailAddress
)

AppTextField(
    title: "비밀번호",
    placeholder: "••••••••",
    text: $password,
    state: .error("8자 이상 입력해야 합니다."),
    isSecure: true
)

AppSearchField(placeholder: "검색", text: $keyword) { search() }
```

상태는 `.normal` / `.error(String)` / `.success(String?)`.

다른 입력 컨트롤에 같은 외형을 쓰려면 모디파이어를 직접 적용한다.

```swift
TextEditor(text: $memo).appFieldContainer(state: .normal, isFocused: isFocused)
```

### 토글

```swift
Toggle("알림 받기", isOn: $isOn).toggleStyle(.appSwitch)
Toggle("약관 동의", isOn: $agreed).toggleStyle(.appCheckbox)
```

---

## 표시

```swift
AppBadge(text: "완료", style: .success, icon: .success)
AppBadge(text: "주의", style: .warning)

AppChip(text: "진행 중", isSelected: filter == .inProgress) {
    filter = .inProgress
}
```

`style`은 `.neutral` / `.accent` / `.success` / `.warning` / `.danger`.

### 목록

```swift
AppSectionHeader(title: "최근 항목", subtitle: "지난 7일") {
    Button("전체 보기") { }.buttonStyle(.appTextButton)
}

AppListRow(icon: .person, title: "계정", subtitle: "프로필과 로그인 정보")  // 셰브런 자동
AppDivider(inset: \.xxxl)
AppListRow(icon: .bell, title: "알림") {
    AppRowDetail(text: "켬")
}
```

### 진행률 · 라벨

```swift
ProgressView("업로드 중", value: 0.65)
    .progressViewStyle(.appLinear(showsPercentage: true))
ProgressView().progressViewStyle(.appLinear)        // 불확정

Label("설정", icon: .settings).labelStyle(.app)
Label("계정", icon: .person).labelStyle(.appTinted)  // 둥근 사각 배경
```

---

## 상태 화면

```swift
AppStatusView.empty(
    title: "아직 항목이 없습니다",
    message: "오른쪽 위 + 버튼으로 첫 항목을 추가해 보세요.",
    action: AppStatusAction(title: "항목 추가") { showEditor = true }
)

AppStatusView.error(message: error.localizedDescription) {
    Task { await viewModel.reload() }
}

AppStatusView.offline { Task { await viewModel.reload() } }
AppStatusView.noResults(keyword: keyword)
```

### 로딩

```swift
AppLoadingView(message: "불러오는 중")

content.appLoadingOverlay(isLoading, message: "처리 중")   // 조작 차단

AppSkeleton(height: 20)
AppSkeleton(height: 80, cornerRadius: \.md)
```

---

## 오버레이

### 토스트

```swift
@State private var toast: AppToast?

content.appToast($toast)

toast = .success("저장했습니다")
toast = .info("링크를 복사했습니다")
toast = .error("저장에 실패했습니다",
               message: "네트워크 연결을 확인해 주세요.",
               retry: { Task { await save() } })
```

프리셋으로 부족하면 직접 만든다. 액션이 있는 토스트는 VoiceOver 사용 중에는 자동으로 닫히지 않는다(버튼까지 이동할 시간을 보장하기 위해서다).

```swift
toast = AppToast(
    kind: .info,
    title: "새 버전이 있습니다",
    duration: AppToast.standardDuration,
    action: AppMessageAction(title: "업데이트") { openStore() }
)
```

연달아 뜨는 토스트를 순서대로 보여주려면 큐를 쓴다.

```swift
@State private var toastQueue = AppToastQueue()

RootView()
    .appToast(queue: toastQueue)
    .environment(toastQueue)

toastQueue.show(.success("완료"))
```

### 배너

```swift
AppBanner(
    kind: .warning,
    title: "알림 권한이 필요합니다",
    message: "설정에서 허용해 주세요.",
    action: AppMessageAction(title: "설정 열기") { openSettings() },
    onDismiss: { isDismissed = true }
)
```

전역 상태 배너는 **붙이는 위치가 배치를 결정한다.**

```swift
// 내비게이션 바 아래 — 화면 콘텐츠에 붙인다
ContentView()
    .appStatusBanner(isPresented: !isOnline, title: "오프라인 상태입니다")

// 내비게이션 바 위 — NavigationStack 바깥에 붙인다
NavigationStack { ContentView() }
    .appStatusBanner(isPresented: !isOnline,
                     title: "오프라인 상태입니다",
                     placement: .aboveNavigationBar)
```

`kind`는 `.info` / `.success` / `.warning` / `.error`.

### 시트

```swift
// detent 지정
content.appSheet(isPresented: $isShowing, detents: [.medium, .large]) {
    AppSheetContainer {
        AppSheetHeader(title: "필터", subtitle: "조건을 선택하세요") {
            isShowing = false
        }
        ForEach(options) { AppListRow(title: $0.title) }
    }
}

// 콘텐츠 높이에 맞춤
content.appFittedSheet(isPresented: $isShowing) {
    AppSheetHeader(title: "정렬") { isShowing = false }
    ForEach(options) { AppListRow(title: $0.title) }
}
```

| 상황 | 선택 |
|---|---|
| 액션 목록, 정렬·필터, 짧은 확인 | `appFittedSheet` |
| 폼 입력, 긴 목록 | `appSheet` + `[.medium, .large]` |

### 다이얼로그

```swift
@State private var dialog: AppDialog?

Button("삭제") {
    dialog = .delete(itemName: item.title) { viewModel.delete(item) }
}
.appDialog($dialog)          // ← 트리거 버튼에 붙여야 iPad 팝오버가 제자리에 뜬다
```

프리셋은 `.delete(itemName:onConfirm:)`(안내 문구 포함), `.delete(itemName:message:onConfirm:)`(안내 문구 교체, `nil` 이면 생략), `.discardChanges(onConfirm:)`.
프리셋으로 부족하면 `AppDialog(title:message:confirmTitle:cancelTitle:isDestructive:onConfirm:)` 로 직접 만든다. 버튼 문구를 생략하면 "확인" / "취소" 다.

화면 루트에 모아 붙여야 한다면 알럿 방식을 쓴다.

```swift
content.appDialog($dialog, presentation: .alert)   // 항상 화면 중앙
```

### 오류 알럿

```swift
@State private var error: AppAlertError?

content.appErrorAlert($error)

error = AppAlertError(message: "서버에 연결할 수 없습니다.", retry: { retry() })
```

---

## 레이아웃

```swift
content.appCard()                       // 표면 + 여백 + 테두리 + 그림자
content.appCard(padding: \.md, radius: \.md, showsBorder: false, shadow: nil)

content.appScreenPadding()              // 사이즈 클래스 대응 좌우 여백
content.appScreenBackground()
content.appReadableWidth()              // 넓은 화면에서 폭 제한 + 가운데 정렬
content.appShadow(\.floating)
```

`.appReadableWidth()`는 iPad 가로 모드에서 본문이 화면 전체로 늘어나는 것을 막는다.

---

## 접근성

```swift
content.appFocusRing(isFocused)
content.appMinimumHitTarget()
content.appDisabled(isDisabled)

cardContent.appAccessibilityElement(
    label: "\(title), \(subtitle)",
    hint: "두 번 탭하면 상세로 이동합니다",
    traits: .isButton
)

AppDivider().appDecorative()
Text("최근 항목").appAccessibilityHeader()
```

접근성 확대에서 가로 배치가 깨지면 축을 바꾼다.

```swift
AppAdaptiveStack(spacing: theme.metrics.spacing.md) {
    Image(.calendar).appIcon(\.md)
    Text(dateText)
    AppBadge(text: "예정", style: .accent)
}
```

VoiceOver 안내가 필요할 때.

```swift
AppAccessibility.announce("저장 완료")
AppAccessibility.announceScreenChange()
```

---

## 햅틱

```swift
AppHaptic.success.trigger()
Toggle("알림", isOn: $isOn).appHaptic(.light, trigger: isOn)
```

`selection` · `light` · `medium` · `heavy` · `success` · `warning` · `error`

`AsyncButton`, `.appPressable`, `AppIconButton`에 기본으로 물려 있고 `haptic: nil`로 끌 수 있다. 실기기에서만 느낄 수 있다.

---

## 프리뷰 헬퍼

```swift
#Preview {
    AppBadge(text: "완료", style: .success)
        .appPreview()
}

#Preview("Variants") {
    AppPreviewVariants {          // 라이트 · 다크 · XXL · RTL 나란히
        MyComponent()
    }
}

#Preview("Contrast") {
    AppContrastInspector()        // 토큰 조합별 대비율 수치
}
```
