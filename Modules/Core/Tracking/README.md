# Tracking

사용자 행동 이벤트를 기록하는 창구. 무엇을 기록할지는 피처가 정하고, 어디로 보낼지(Firebase Analytics, 로그)는 App이 꽂는다.
이 모듈은 전송 수단을 모른다.

**iOS 17.0+ / Xcode 27+ / Swift 6 · Foundation과 `os`만 import한다**

---

## 구성

```
Modules/Core/Tracking/
├── Sources/
│   ├── EventTracking.swift        기록 창구 프로토콜. 피처가 주입받는다
│   ├── TrackingEvent.swift        이벤트 하나(이름, 파라미터)
│   ├── TrackingValue.swift        파라미터 값(string, int, double)
│   └── LoggerEventTracker.swift   os.Logger 로만 남기는 기본 구현
├── Testing/Sources/               (TrackingTesting)
│   └── SpyEventTracker.swift      받은 이벤트를 기록
└── Tests/

App/Sources/
├── Tracking/FirebaseEventTracker.swift   이벤트 → Analytics.logEvent
└── DI/AppContainer.swift                 Firebase 를 초기화했을 때만 FirebaseEventTracker, 아니면 LoggerEventTracker
```

---

## 사용법

### 피처에서 기록하기

피처는 `any EventTracking`을 생성자로 받는다. 구체 타입을 만들지 않는다.

```swift
import Tracking

enum HomeEvent {
    static let itemSelected = "home_item_selected"
}

@Observable
final class HomeViewModel {
    private let tracker: any EventTracking

    init(tracker: any EventTracking) {
        self.tracker = tracker
    }

    func select(_ item: Item) {
        tracker.track(TrackingEvent(name: HomeEvent.itemSelected, parameters: ["id": .string(item.id)]))
    }
}
```

- 이벤트 이름은 피처 모듈의 `enum` 네임스페이스에 상수로 둔다. 호출부에 문자열을 직접 쓰지 않는다.
- 피처 `Project.swift`의 `dependencies`에 `.module(.tracking)`을 추가한다.
- `track(_:)`은 동기이고 실패를 돌려주지 않는다.

### 테스트에서 `SpyEventTracker` 쓰기

테스트 타깃에 `.module(.tracking)`과 `.testing(.tracking)`을 추가한다.

```swift
import Tracking
import TrackingTesting

let tracker = SpyEventTracker()
let viewModel = HomeViewModel(tracker: tracker)

viewModel.select(item)

#expect(tracker.events.map(\.name) == [HomeEvent.itemSelected])
```

데모 앱이나 프리뷰에서는 `LoggerEventTracker(logger:)`를 쓰면 된다.

### Console에서 보기

`LoggerEventTracker`는 `이벤트: <name> {key=value, ...}` 한 줄을 남긴다. 파라미터는 키 순서로 정렬하고,
사용자 값이 들어갈 수 있어 비공개(`<private>`)로 남긴다. 디버거를 붙이면 값이 보인다.

---

## 이름과 파라미터 제약

이 모듈은 이름과 파라미터를 검증하지 않는다. 제약은 전송 수단마다 다르기 때문이다.
지금 쓰는 Firebase Analytics(12.19.2, `FIRAnalytics.h`의 `logEventWithName:parameters:` 문서)의 제약은 다음과 같다. 이름을 정할 때 지킨다.

| 대상 | 제약 |
|---|---|
| 이벤트 이름 | 1~40자, 영숫자와 `_`만, 영문자로 시작. 대소문자를 구분한다 |
| 파라미터 이름 | 최대 40자, 영숫자와 `_`만, 영문자로 시작 |
| 문자열 값 | 최대 100자(표준 속성 기준) |
| 예약 접두사 | `firebase_`, `google_`, `ga_`는 이벤트·파라미터 이름에 쓰지 않는다 |
| 예약 이벤트 이름 | `first_open`, `session_start`, `error`, `app_update` 등. 목록은 `FIRAnalytics.h`와 `FIREventNames.h`에 있다 |

화면 조회를 직접 남기려면 이벤트 이름 `screen_view`를 쓴다. 이벤트당 파라미터 개수 한도는 헤더에 적혀 있지 않아 여기서는 정하지 않는다.
