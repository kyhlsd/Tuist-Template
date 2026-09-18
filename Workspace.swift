//
//  Workspace.swift
//  _TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: AppConstants.appName,
    projects: [
        "App",
        "Modules/**",
    ],
    additionalFiles: [
        "Configurations/**",
        "README.md",
    ]
)
