# FeatureFlags

기능을 켜고 끄는 Bool 플래그를 읽는 창구. 어떤 플래그가 있는지는 피처가 선언하고, 값을 어디서 가져올지(Firebase Remote Config, 기본값)는 App이 꽂는다.
이 모듈은 값 출처를 모른다.

**iOS 17.0+ / Xcode 27+ / Swift 6 · Foundation과 `os`만 import한다**

---

## 구성

```
Modules/Core/FeatureFlags/
├── Sources/
│   ├── FeatureFlag.swift                  플래그 하나(키, 기본값)
│   ├── FeatureFlagProviding.swift         조회 창구 프로토콜. 피처가 주입받는다
│   └── DefaultFeatureFlagProvider.swift   항상 기본값을 돌려주는 기본 구현
├── Testing/Sources/                       (FeatureFlagsTesting)
│   └── StubFeatureFlagProvider.swift      지정한 플래그만 원하는 값으로
└── Tests/

App/Sources/
├── FeatureFlags/RemoteConfigFeatureFlagProvider.swift   Remote Config 값, 시작할 때 한 번 받아서 적용
└── DI/AppContainer.swift                                Firebase 를 초기화했을 때만 Remote Config, 아니면 기본값
```

---

## 사용법

### 플래그 선언하기

피처가 자기 모듈에서 `FeatureFlag`를 확장해 선언한다. 기본값은 이 선언이 유일한 출처다(Remote Config 콘솔이나 plist에 기본값을 따로 두지 않는다).

```swift
import FeatureFlags

extension FeatureFlag {
    static let homeBanner = FeatureFlag(key: "home_banner_enabled", defaultValue: false)
}
```

- 키는 Remote Config 콘솔의 파라미터 이름과 같아야 한다.
- 콘솔에서 파라미터의 데이터 유형을 **Boolean**으로 둔다. 문자열로 두고 `"on"`처럼 Bool로 읽히지 않는 값을 넣으면 선언한 기본값이 아니라 `false`가 된다(원격 값이 있다고 보고 SDK의 `boolValue`를 그대로 쓰기 때문이다).
- 기본값은 "원격 값을 한 번도 받지 못했을 때"의 동작이다. 안전한 쪽(대개 `false`)으로 둔다.

### 피처에서 읽기

```swift
@Observable
final class HomeViewModel {
    private let featureFlags: any FeatureFlagProviding

    init(featureFlags: any FeatureFlagProviding) {
        self.featureFlags = featureFlags
    }

    var showsBanner: Bool {
        featureFlags.isEnabled(.homeBanner)
    }
}
```

- 피처 `Project.swift`의 `dependencies`에 `.module(.featureFlags)`를 추가한다.

### 테스트에서 `StubFeatureFlagProvider` 쓰기

테스트 타깃에 `.module(.featureFlags)`와 `.testing(.featureFlags)`를 추가한다.

```swift
import FeatureFlags
import FeatureFlagsTesting

let viewModel = HomeViewModel(featureFlags: StubFeatureFlagProvider(overrides: [.homeBanner: true]))

#expect(viewModel.showsBanner)
```

데모 앱이나 프리뷰에서는 `DefaultFeatureFlagProvider()`를 쓰면 된다.

---

## 값이 반영되는 시점

App은 시작할 때 Remote Config를 한 번 받아서 바로 적용한다(`fetchAndActivate`). 그래서:

- **받기 전에는 지난 실행에서 적용한 값**을 읽는다. 한 번도 받은 적이 없으면 `defaultValue`다.
- **받은 뒤에는 새 값**을 읽는다. 세션 초반에 값이 한 번 바뀔 수 있다.
- **이미 읽은 화면은 다시 읽지 않는다.** 바뀐 값을 알려주는 장치가 없다. 첫 화면에서 읽은 플래그는 다음 실행부터 반영된다고 보면 된다.
- Remote Config는 받은 값을 12시간(기본 `minimumFetchInterval`) 동안 재사용한다. 콘솔에서 바꾼 값이 곧바로 보이지 않을 수 있다.
- Debug와 설정 파일(`GoogleService-Info.plist`)이 없을 때는 Firebase를 초기화하지 않으므로 항상 `defaultValue`다.

플래그를 쓰는 피처는 이 점을 보고 읽는 시점을 정한다. 화면이 도중에 바뀌면 안 되는 플래그는 화면을 만들 때 한 번만 읽는다.
