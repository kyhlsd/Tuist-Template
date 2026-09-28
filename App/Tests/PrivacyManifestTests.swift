//
//  PrivacyManifestTests.swift
//  TuistAppTests
//

import Foundation
import Testing

/// `App/Resources/PrivacyInfo.xcprivacy` 가 앱 번들에 실리고 plist 로 읽히는지 확인한다.
///
/// 파일이 빠지거나 XML 이 깨져도 빌드는 성공하고, App Store 제출 단계에서야 드러난다.
@Suite("Privacy Manifest")
struct PrivacyManifestTests {
    @Test("앱 번들의 매니페스트가 필수 키를 모두 가진다")
    func manifest_inMainBundle_hasRequiredKeys() throws {
        let url = try #require(Bundle.main.url(forResource: Manifest.name, withExtension: Manifest.fileExtension))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try #require(plist as? [String: Any])

        #expect(Set(manifest.keys).isSuperset(of: Manifest.requiredKeys))
    }

    @Test("추적하지 않는다고 선언한다")
    func manifest_tracking_isFalse() throws {
        let url = try #require(Bundle.main.url(forResource: Manifest.name, withExtension: Manifest.fileExtension))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try #require(plist as? [String: Any])

        #expect(manifest[Manifest.trackingKey] as? Bool == false)
    }

    @Test("UserDefaults 사용 사유를 앱 전용(CA92.1)으로 선언한다")
    func manifest_userDefaults_declaresAppOnlyReason() throws {
        let url = try #require(Bundle.main.url(forResource: Manifest.name, withExtension: Manifest.fileExtension))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try #require(plist as? [String: Any])
        let accessedTypes = try #require(manifest[Manifest.accessedAPITypesKey] as? [[String: Any]])
        let userDefaults = try #require(accessedTypes.first {
            $0[Manifest.accessedAPITypeKey] as? String == Manifest.userDefaultsCategory
        })

        #expect(userDefaults[Manifest.accessedAPIReasonsKey] as? [String] == [Manifest.userDefaultsAppOnlyReason])
    }

    private enum Manifest {
        static let name = "PrivacyInfo"
        static let fileExtension = "xcprivacy"
        static let trackingKey = "NSPrivacyTracking"
        static let accessedAPITypesKey = "NSPrivacyAccessedAPITypes"
        static let accessedAPITypeKey = "NSPrivacyAccessedAPIType"
        static let accessedAPIReasonsKey = "NSPrivacyAccessedAPITypeReasons"
        static let userDefaultsCategory = "NSPrivacyAccessedAPICategoryUserDefaults"
        static let userDefaultsAppOnlyReason = "CA92.1"
        static let requiredKeys: Set = [
            trackingKey,
            "NSPrivacyTrackingDomains",
            "NSPrivacyCollectedDataTypes",
            accessedAPITypesKey,
        ]
    }
}
