//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// Domain 은 아무것도 모른다. Foundation 외에는 import 하지 않는다.
/// SwiftUI 나 네트워킹 라이브러리가 여기 들어오면 레이어가 무너진 것이다.
///
/// DomainTesting 에는 Repository 스텁과 픽스처를 둔다. 다른 모듈의 테스트·데모가
/// `.testing(.domain)` 으로 가져다 쓴다.
let project = Project.core(
    name: "Domain",
    hasTestingSupport: true
)
