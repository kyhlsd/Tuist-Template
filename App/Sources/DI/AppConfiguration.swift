//
//  AppConfiguration.swift
//  TuistApp
//

import Foundation

/// 환경별 설정값. xcconfig → Info.plist 를 거쳐 들어온다.
struct AppConfiguration: Sendable {
    let apiBaseURL: URL

    /// 앱 번들의 Info.plist 에서 읽는다.
    ///
    /// 값이 없으면 xcconfig 나 `InfoPlist.runnable` 설정이 깨진 것이므로
    /// 실행을 이어가지 않는다.
    static func fromMainBundle() -> AppConfiguration {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: InfoKey.apiBaseURL) as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("Info.plist 의 \(InfoKey.apiBaseURL) 이 비어 있거나 URL 이 아닙니다. Configurations/*.xcconfig 를 확인하세요.")
        }
        return AppConfiguration(apiBaseURL: url)
    }

    private enum InfoKey {
        static let apiBaseURL = "API_BASE_URL"
    }
}
