//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/23/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// Bool 플래그 선언(`FeatureFlag`)과 조회 창구(`FeatureFlagProviding`), 기본값 제공자를 둔다.
/// Foundation 과 os 외에는 import 하지 않는다.
///
/// Firebase Remote Config 같은 값 출처는 App 이 `FeatureFlagProviding` 구현으로 꽂는다. 이 모듈은 출처를 모른다.
///
/// FeatureFlagsTesting 에는 고정 값 스텁을 둔다. 다른 모듈의 테스트·데모가
/// `.testing(.featureFlags)` 로 가져다 쓴다.
let project = Project.core(
    name: "FeatureFlags",
    hasTestingSupport: true
)
