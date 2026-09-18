//
//  Tuist.swift
//  Config
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription

let tuist = Tuist(project: .tuist(
    compatibleXcodeVersions: .upToNextMajor("27.0"),
    generationOptions: .options(
        enforceExplicitDependencies: true
    )
))
