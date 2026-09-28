# Firebase 설정 파일

구성마다 Firebase 콘솔에서 받은 `GoogleService-Info.plist` 를 둔다. 비밀 값이 아니라 커밋한다.

```
Configurations/Firebase/
  Staging/GoogleService-Info.plist   번들 ID <앱 번들 ID>.stg 로 등록한 Firebase 앱
  Release/GoogleService-Info.plist   번들 ID <앱 번들 ID> 로 등록한 Firebase 앱
```

- 앱 빌드 단계의 `Scripts/firebase-copy-config.sh` 가 지금 구성의 파일을 앱 번들에 복사한다.
  파일이 없으면 번들에서도 지우고, Firebase 는 초기화를 건너뛰어 로그로만 동작한다(`FirebaseBootstrap`).
- Debug 는 Firebase 를 쓰지 않으므로 폴더를 두지 않는다.
- Staging 과 Release 는 같은 Firebase 프로젝트의 두 앱으로 등록해도, 프로젝트를 나눠도 된다.
  QA 빌드의 크래시·이벤트가 운영 지표에 섞이지 않게 하려면 프로젝트를 나눈다.
