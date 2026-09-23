//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/23/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 이벤트 기록 창구(`EventTracking`)와 값 타입, 기본 로그 기록기(`LoggerEventTracker`)를 둔다.
/// Foundation 과 os 외에는 import 하지 않는다.
///
/// Firebase Analytics 같은 전송 수단은 App 이 `EventTracking` 구현으로 꽂는다. 이 모듈은 수단을 모른다.
///
/// TrackingTesting 에는 기록 스파이를 둔다. 다른 모듈의 테스트가
/// `.testing(.tracking)` 으로 가져다 쓴다.
let project = Project.core(
    name: "Tracking",
    hasTestingSupport: true
)
