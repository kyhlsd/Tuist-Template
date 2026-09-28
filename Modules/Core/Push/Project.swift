//
//  Project.swift
//  TuistAppManifests
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 푸시 payload 규약. 앱과 Notification Service Extension 이 함께 쓴다.
/// Foundation 외에는 import 하지 않는다. 알림 표시·권한은 앱과 익스텐션이 UserNotifications 로 직접 다룬다.
let project = Project.core(
    name: "Push"
)
