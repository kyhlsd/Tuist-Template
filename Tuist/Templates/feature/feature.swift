//
//  feature.swift
//  Templates
//
//  Feature 모듈 스캐폴드. 직접 부르지 말고 Scripts/new-module.sh 로 실행한다.
//  scaffold 는 기존 파일을 고치지 못하므로 Module.swift 등록과 옵션 폴더 정리는 스크립트가 한다.
//
//  조건부 파일 생성이 없어서(tuist/tuist#6862) 옵션 폴더(Demo, Testing, Resources)도 항상 만든다.
//  CLI 로 넘긴 값은 모두 문자열이라 .stencil 에서는 `{% if demo == "true" %}` 로 비교한다.
//  Project.stencil 끝의 빈 줄은 지우지 않는다. Stencil 이 줄 끝 태그 뒤의 줄바꿈 하나를 삼킨다.
//

import ProjectDescription

private let root = "Modules/Features/{{ name }}"

let template = Template(
    description: "Feature 모듈(Interface, 구현, 테스트, 선택: Testing, Demo, Resources)",
    attributes: [
        .required("name"),
        .optional("demo", default: .string("false")),
        .optional("testing", default: .string("false")),
        .optional("resources", default: .string("false")),
    ],
    items: [
        .file(path: "\(root)/Project.swift", templatePath: "Project.stencil"),
        .file(path: "\(root)/Interface/Sources/{{ name }}Route.swift", templatePath: "Route.stencil"),
        .file(path: "\(root)/Sources/{{ name }}View.swift", templatePath: "View.stencil"),
        .file(path: "\(root)/Tests/{{ name }}Tests.swift", templatePath: "Tests.stencil"),
        .file(path: "\(root)/Testing/Sources/{{ name }}Route+Fixtures.swift", templatePath: "Fixtures.stencil"),
        .file(path: "\(root)/Demo/Sources/{{ name }}DemoApp.swift", templatePath: "DemoApp.stencil"),
        .file(path: "\(root)/Resources/Localizable.xcstrings", templatePath: "Localizable.xcstrings.stencil"),
    ]
)
