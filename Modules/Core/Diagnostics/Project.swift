//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/22/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 진단 타입(`DiagnosticFailure`, `Breadcrumb`), 중복 억제(`DiagnosticReporter`),
/// 기본 로그 싱크(`LoggerDiagnosticSink`)를 둔다. Foundation 과 os 외에는 import 하지 않는다.
///
/// Firebase 같은 전송 수단은 App 이 `DiagnosticEventSink` 싱크로 꽂는다. 이 모듈은 수단을 모른다.
///
/// DiagnosticsTesting 에는 보고·기록 스파이를 둔다. 다른 모듈의 테스트가
/// `.testing(.diagnostics)` 로 가져다 쓴다.
let project = Project.core(
    name: "Diagnostics",
    hasTestingSupport: true
)
