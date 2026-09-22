# Diagnostics

클라이언트에서만 보이는 실패를 모아 보고하는 모듈. 무엇을 보고할지는 Data가 정하고, 어디로 보낼지(Crashlytics, 로그)는 App이 싱크로 꽂는다.
이 모듈은 전송 수단을 모른다.

**iOS 17.0+ / Xcode 27+ / Swift 6 · Foundation과 `os`만 import한다**

---

## 특징

- **서버가 볼 수 없는 에러만 보고**: 전송 실패(연결 불가, 타임아웃)와 응답 디코딩 실패만 올린다. 취소, 오프라인류 `URLError`, 인증 만료는 보고하지 않는다. 판정은 Networking의 `NetworkFailure.isReportable`이 한다.
- **서버 로그와 연결**: 모든 요청에 `X-Request-ID`가 붙고, 보고와 breadcrumb에 같은 값(`requestID`, `rid=`)이 남는다. 서버가 받지 못한 요청(전송 실패)의 보고에는 ID가 없지만 breadcrumb에는 남는다.
- **같은 에러는 5분에 한 번**: `DiagnosticReporter`가 fingerprint(operation × 에러 타입(case) × 코드)별로 마지막 전송 시각을 기억한다. 반복 에러가 Crashlytics의 비치명 슬롯을 밀어내지 않는다.
- **breadcrumb**: 끝난 요청마다 `"GET /items 200 123ms rid=…"` 한 줄이 남는다. Crashlytics에서는 비치명 에러와 크래시 리포트 양쪽에 붙는다.
- **전송 수단은 싱크로 교체**: `DiagnosticEventSink & BreadcrumbRecording`을 구현하면 된다. 보고하는 쪽(Data)은 그대로다.
- **Debug와 설정 파일이 없을 때는 로그로만**: Firebase를 초기화하지 않고 `LoggerDiagnosticSink`가 Console에 남긴다. 무엇이 보고될지 Debug에서 확인할 수 있다.
- **취소는 info**: 취소로 끝난 요청의 breadcrumb는 에러가 아니라 info 레벨이다.
- **요약값만**: 에러 설명, URL 쿼리, 헤더, 바디는 담지 않는다. 타입 이름, 코드, operation ID, request ID뿐이다.

---

## 구성

```
Modules/Core/Diagnostics/
├── Sources/
│   ├── DiagnosticFailure.swift       보고할 실패 하나(요약값), fingerprint
│   ├── DiagnosticReporting.swift     보고 창구 프로토콜. Data 가 주입받는다
│   ├── DiagnosticReporter.swift      중복 억제(actor). 통과한 것만 싱크로
│   ├── DiagnosticEventSink.swift     실패를 내보내는 곳(전송 수단 경계)
│   ├── BreadcrumbRecording.swift     breadcrumb 를 남기는 곳
│   ├── Breadcrumb.swift / BreadcrumbLevel.swift
│   ├── DiagnosticDefaults.swift      억제 간격(5분)
│   └── LoggerDiagnosticSink.swift    os.Logger 로만 남기는 기본 싱크
├── Testing/Sources/                  (DiagnosticsTesting)
│   ├── SpyDiagnosticReporter.swift   억제 없이 보고를 기록
│   ├── SpyDiagnosticEventSink.swift  받은 실패를 기록
│   └── SpyBreadcrumbRecorder.swift   받은 breadcrumb 를 기록
└── Tests/

Modules/Core/Networking/Sources/
├── Diagnostics/NetworkFailure.swift            에러 요약, 보고 대상·취소 판정
├── Diagnostics/NetworkActivityObserving.swift  요청이 끝날 때마다 NetworkRequestRecord 를 알림
└── Middleware/RequestIDMiddleware.swift        X-Request-ID 부여

Modules/Core/Data/Sources/RemoteItemRepository.swift   catch 에서 NetworkFailure → DiagnosticFailure 로 바꿔 보고

App/Sources/
├── Diagnostics/FirebaseBootstrap.swift         Release 이고 plist 가 있을 때만 Firebase 초기화
├── Diagnostics/CrashlyticsDiagnosticSink.swift 보고 → 비치명 에러, breadcrumb → Crashlytics 로그
├── Diagnostics/NetworkBreadcrumbAdapter.swift  NetworkRequestRecord → Breadcrumb
└── DI/AppContainer.swift                       싱크 선택과 조립
```

Networking은 이 모듈을 모른다. 요청 요약은 `NetworkActivityObserving`으로 밖에 알리고, App이 breadcrumb로 바꾼다.
`NetworkFailure`를 `DiagnosticFailure`로 바꾸는 일은 둘을 모두 아는 Data가 한다.

```
App ──→ Data ──→ Diagnostics
 │        └───→ Networking
 ├──→ Diagnostics   (싱크 선택, LoggerDiagnosticSink)
 └──→ Networking    (NetworkBreadcrumbAdapter 가 옵저버를 구현)
```

흐름은 두 갈래다.

```
보고:        Repository catch → NetworkFailure.describe → isReportable?
               → DiagnosticReporter.report → (5분 억제) → 싱크.send
breadcrumb:  LoggingMiddleware → NetworkActivityObserving.requestFinished
               → NetworkBreadcrumbAdapter → 싱크.record
```

---

## 사용법

### 새 Repository에서 보고하기

생성 클라이언트를 부르는 `catch`에서 판정하고, 보고 대상일 때만 보낸다. 응답 디코딩 실패는 미들웨어에 보이지 않고 여기서만 잡히므로 이 자리가 보고 지점이다.

```swift
import Diagnostics
import Networking

public struct RemoteOrderRepository: OrderRepository {
    private let client: any APIProtocol
    private let reporter: any DiagnosticReporting

    public func fetchOrders() async throws(OrderError) -> [Order] {
        let output: Operations.ListOrders.Output
        do {
            output = try await client.listOrders()
        } catch {
            report(error)
            throw .unavailable
        }
        ...
    }

    private func report(_ error: any Error) {
        let failure = NetworkFailure.describe(error)
        guard failure.isReportable else {
            return
        }
        reporter.report(DiagnosticFailure(
            operationID: failure.operationID,
            errorType: failure.errorType,
            errorCode: failure.errorCode,
            summary: failure.summary,
            requestID: failure.requestID
        ))
    }
}
```

- `report(_:)`는 기다리지 않는다. 호출부의 에러 처리를 늦추지 않는다.
- App은 `AppContainer`가 만든 `DiagnosticReporter` 하나를 모든 Repository에 넘긴다. 중복 억제를 앱 전체에서 공유하기 위해서다.
- 모듈 `Project.swift`의 `dependencies`에 `.module(.diagnostics)`를 추가한다.

### 테스트에서 `SpyDiagnosticReporter` 쓰기

테스트 타깃에 `.module(.diagnostics)`와 `.testing(.diagnostics)`를 추가한다.

```swift
import Diagnostics
import DiagnosticsTesting

let reporter = SpyDiagnosticReporter()
let repository = RemoteItemRepository(client: stub, reporter: reporter)

_ = try? await repository.fetchItems()

#expect(reporter.reported.map(\.operationID) == ["listItems"])
```

- `SpyDiagnosticReporter`는 억제 없이 호출 즉시 기록한다. 기다릴 필요가 없다.
- 억제 로직 자체를 볼 때는 `DiagnosticReporter(sink: SpyDiagnosticEventSink(), now: 고정 시계)`를 쓴다(`DiagnosticReporterTests` 참고).
- breadcrumb를 확인하려면 `SpyBreadcrumbRecorder.breadcrumbs`를 본다.

### 새 싱크 만들기

```swift
struct MyDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording {
    func send(_ failure: DiagnosticFailure) { ... }    // 동기. 대기열·재전송은 전송 수단이 맡는다
    func record(_ breadcrumb: Breadcrumb) { ... }     // 동기. 부른 순서가 기록 순서다
}
```

- 중복 억제는 `DiagnosticReporter`가 하므로 싱크는 받은 대로 내보낸다.
- `Sendable`이어야 한다. non-Sendable SDK 객체는 저장하지 말고 호출할 때마다 받는다(`CrashlyticsDiagnosticSink` 참고).
- `AppContainer.makeDiagnosticSink(firebaseDecision:logger:)`에서 고른다. 분기를 바꾸면 `AppContainerDiagnosticSinkTests`도 고친다.
- 데모 앱이나 프리뷰에서는 `LoggerDiagnosticSink(logger:)`를 그대로 쓰면 된다.

### Console에서 보기

subsystem은 앱 번들 ID다(Debug는 `.dev`가 붙는다).

| category | 내용 |
|---|---|
| `Networking` | 요청 로그(`rid=` 포함) |
| `Diagnostics` | `LoggerDiagnosticSink`의 breadcrumb와 `보고: <operation> <errorType>(<code>) <summary> rid=<id>`, 싱크 선택 사유 |

Debug로 실행해 개발 서버 없이 목록을 불러오면 `보고:` 줄이 한 번 찍히고, 5분 안에 다시 시도하면 찍히지 않는다.

---

## Crashlytics 켜기

지금은 `GoogleService-Info.plist`가 없어서 Release에서도 Firebase를 초기화하지 않는다. 앱은 크래시 없이 로그 싱크로 동작하고 dSYM 업로드는 경고만 남기고 건너뛴다.
파일만 넣으면 다음 Release 빌드부터 켜진다.

1. Firebase 콘솔에서 번들 ID `com.olivebridge.tuistapp`로 iOS 앱을 등록한다. App Check를 켜고 API 키 제한을 건다.
2. `GoogleService-Info.plist`를 `App/Resources/`에 넣고 커밋한다.
3. `./.claude/scripts/xcbuild.sh build -configuration Release`를 돌려 dSYM 업로드 스크립트가 실행되는지(경고가 사라지는지) 본다.
4. Release 빌드를 디버거 없이 실행하고 보고 대상 실패를 일으킨다. 앱을 다시 실행한 뒤 대시보드의 비치명 에러와 로그 탭을 확인한다. 필요하면 `-FIRDebugEnabled` 실행 인자로 "Completed report submission"을 확인한다.
5. 개인정보 처리방침과 App Store Connect App Privacy에 Crash Data와 기타 진단 데이터(사용자에 연결되지 않음, 추적 아님)를 선언한다.

Debug는 plist가 있어도 수집하지 않는다(시끄럽고 dSYM이 없으며 테스트 호스트도 Debug다).

### 대시보드에서 읽기

| 위치 | 값 |
|---|---|
| 이슈 domain | `network.<operationID>.<errorType>`. operation을 모르면 `unknown` |
| code | `URLError` 코드. 없으면 `0` |
| userInfo `summary` | `URLError(-1004)`, `DecodingError` 같은 한 단어 요약 |
| userInfo `requestID` | 서버 로그에서 찾을 ID. 전송 실패면 없다 |
| 로그 탭 | 그 세션의 breadcrumb(`[network] GET /items 200 123ms rid=…`) |

Crashlytics는 domain과 code로 이슈를 묶는다. 같은 operation의 같은 에러가 하나의 이슈로 모인다.

---

## 한도와 주의

- **비치명 에러는 세션당 8개**이고 **다음 실행 때** 전송된다. 5분 억제가 이 슬롯을 지킨다.
- **Crashlytics 로그는 세션당 64KB**다. 넘치면 오래된 것부터 지워진다. 그래서 취소는 info로 남기고 breadcrumb는 한 줄로 짧게 둔다.
- **연관값이 없는 enum case는 타입 이름만** 남는다. `DecodingError.dataCorrupted`처럼 case가 붙는 것은 연관값이 있는 case뿐이다. 연관값에는 URL이 들어갈 수 있어 case 이름만 쓴다.
- **refresh 실패는 `refreshToken`으로 보고된다**. 토큰 갱신이 전송 단계에서 실패하면 refresh 클라이언트의 에러가 그대로 올라오므로, `listItems`를 불렀어도 operation은 실제로 실패한 `refreshToken`이다.
- breadcrumb의 path는 쿼리를 뺀 값이다. 경로에 개인정보가 들어가는 API가 생기면 operation ID로 바꾼다.
- 보고 지점은 Repository의 `catch`다. 새 Repository에서 빠뜨리지 않도록 위 "새 Repository에서 보고하기"를 따른다.
