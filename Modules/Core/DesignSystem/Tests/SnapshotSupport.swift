//
//  SnapshotSupport.swift
//  DesignSystemTests
//
//  ⚠️ 테스트 타깃에 포함한다.
//

@testable import DesignSystem
import SwiftUI
import UIKit

/// 외부 의존성 없이 SwiftUI 뷰를 이미지로 렌더링해 비교한다.
///
/// `ImageRenderer`(iOS 16+)를 쓰므로 시뮬레이터 실행 없이도 동작하며,
/// 컴포넌트 외형이 의도치 않게 바뀌었는지 CI에서 잡을 수 있다.
///
/// - Important: 기준 이미지는 OS 버전과 렌더링 엔진 변화에 민감하다.
///   OS를 올린 뒤에는 차이를 눈으로 확인하고 기준 이미지를 갱신해야 한다.
@MainActor
enum Snapshot {
    /// 스냅샷 비교가 가능한 환경인지.
    ///
    /// 기준 이미지는 컴파일 시점의 소스 경로(`#filePath`)에 기록하는데,
    /// 이는 Mac의 경로다. 시뮬레이터는 호스트 파일 시스템에 쓸 수 있지만,
    /// 실기기에는 그 경로가 존재하지 않고 샌드박스 밖으로 쓸 수도 없다. 기기·해상도에 따라 렌더링 결과가 달라져 비교 자체도
    /// 무의미하므로, 스냅샷 테스트는 시뮬레이터 한 기종으로 고정해 실행한다.
    ///
    /// - Note: 컴파일 타임에 결정되는 값이므로 액터 격리가 필요 없다.
    ///   `@Suite`의 특성에서 참조하려면 격리를 풀어야 한다.
    nonisolated static var isSupportedEnvironment: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    /// 기준 이미지가 없을 때 자동으로 생성할지 여부.
    ///
    /// 새 컴포넌트를 추가하고 한 번 켠 뒤 반드시 다시 끈다.
    /// 켜 둔 채로 두면 외형이 바뀌어도 테스트가 항상 통과한다.
    static var isRecording = false

    /// 픽셀 차이 허용 비율. 안티앨리어싱 등 미세한 차이를 흡수한다.
    static var tolerance: Double = 0.01

    // MARK: - 렌더링

    /// 뷰를 지정한 조건으로 렌더링한다.
    static func render(
        _ view: some View,
        size: CGSize,
        theme: Theme = .standard,
        colorScheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .large,
        scale: CGFloat = 2
    ) -> UIImage? {
        let configured = view
            .frame(width: size.width, height: size.height)
            .theme(theme)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dynamicTypeSize, dynamicTypeSize)

        let renderer = ImageRenderer(content: configured)
        renderer.scale = scale
        // 뷰가 안전영역을 참조하지 않도록 명시적 크기를 고정한다.
        renderer.proposedSize = ProposedViewSize(size)

        return renderer.uiImage
    }

    // MARK: - 비교

    /// 렌더링 결과를 기준 이미지와 비교한다.
    ///
    /// - Returns: 일치하면 `nil`, 다르면 실패 사유.
    static func compare(
        _ view: some View,
        named name: String,
        size: CGSize = CGSize(width: 320, height: 200),
        theme: Theme = .standard,
        colorScheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .large,
        file: StaticString = #filePath
    ) -> String? {
        guard let rendered = render(
            _: view,
            size: size,
            theme: theme,
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        ) else {
            return "뷰를 렌더링하지 못했습니다: \(name)"
        }

        let parts: [String?] = [
            name,
            colorScheme == .dark ? "dark" : "light",
            dynamicTypeSize.isAccessibilitySize ? "a11y" : nil,
        ]
        let identifier = parts.compactMap(\.self).joined(separator: "-")

        let recordURL = recordRoot(file: file).appendingPathComponent("\(identifier).png")

        guard let referenceURL = referenceURL(for: identifier) else {
            guard isRecording else {
                return """
                기준 이미지가 없습니다: \(identifier)
                Snapshot.isRecording = true 로 한 번 실행해 생성한 뒤, 새 이미지가 테스트 번들에 들어가도록
                tuist generate 후 다시 실행하세요.
                """
            }

            do {
                try write(rendered, to: recordURL)
                return nil
            } catch {
                return """
                기준 이미지를 저장하지 못했습니다: \(identifier)
                경로: \(recordURL.path)
                원인: \(error.localizedDescription)
                쓰기가 막힌 환경이라면 SNAPSHOT_DIR 환경 변수로 경로를 지정하세요.
                """
            }
        }

        guard
            let referenceData = try? Data(contentsOf: referenceURL),
            let reference = UIImage(data: referenceData)
        else {
            return "기준 이미지를 읽지 못했습니다: \(identifier) (\(referenceURL.path))"
        }

        let difference = pixelDifference(between: rendered, and: reference)

        if difference <= tolerance {
            return nil
        }

        // 실패 시 실제 결과를 남겨 눈으로 비교할 수 있게 한다.
        let failureURL = recordURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Failures__/\(identifier).png")
        try? write(rendered, to: failureURL)

        let percentage = String(format: "%.2f", difference * 100)
        return "외형이 달라졌습니다: \(identifier) (차이 \(percentage)%). 실제 결과: \(failureURL.path)"
    }

    // MARK: - 픽셀 비교

    /// 두 이미지의 평균 채널 차이 비율. 0(동일) ~ 1(완전히 다름).
    private static func pixelDifference(between lhs: UIImage, and rhs: UIImage) -> Double {
        guard
            let left = lhs.cgImage,
            let right = rhs.cgImage,
            left.width == right.width,
            left.height == right.height
        else {
            return 1
        }

        guard
            let leftBytes = pixelBytes(of: left),
            let rightBytes = pixelBytes(of: right),
            leftBytes.count == rightBytes.count,
            !leftBytes.isEmpty
        else {
            return 1
        }

        var total = 0
        for index in leftBytes.indices {
            total += abs(Int(leftBytes[index]) - Int(rightBytes[index]))
        }

        return Double(total) / Double(leftBytes.count * 255)
    }

    private static func pixelBytes(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    // MARK: - 파일

    enum SnapshotError: LocalizedError {
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .pngEncodingFailed: "PNG로 변환하지 못했습니다."
            }
        }
    }

    /// `SNAPSHOT_DIR` 환경 변수. 설정되면 기준 이미지를 이 디렉터리에서 읽고 이곳에 기록한다.
    ///
    /// 소스 디렉터리에 쓸 수 없는 환경(샌드박스 제한이 강한 CI 등)에서 쓴다.
    /// Scheme의 Test 액션이나 `TEST_RUNNER_SNAPSHOT_DIR`로 넘긴다.
    private static var overrideRoot: URL? {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// 새 기준 이미지와 실패 이미지를 기록할 디렉터리. 기본값은 테스트 소스 옆의 `__Snapshots__`다.
    ///
    /// 기록은 시뮬레이터 프로세스가 직접 파일을 만드는 것이라 보호된 폴더(~/Desktop 등)에서도 된다.
    private static func recordRoot(file: StaticString) -> URL {
        overrideRoot ?? URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
    }

    /// 비교에 쓸 기준 이미지. 없으면 `nil`.
    ///
    /// 소스 경로가 아니라 **테스트 번들**에서 읽는다. 저장소가 보호된 폴더(~/Desktop, ~/Documents)에 있으면
    /// 시뮬레이터 프로세스가 자기가 만들지 않은 파일(git이 체크아웃한 기준 이미지)을 읽지 못해,
    /// 저장소 위치에 따라 결과가 달라진다. 번들에는 빌드할 때 Xcode가 복사하므로 위치와 무관하게 읽힌다.
    /// (`Project+Templates.swift`의 `hasSnapshotTests` 참고)
    private static func referenceURL(for identifier: String) -> URL? {
        if let overrideRoot {
            let url = overrideRoot.appendingPathComponent("\(identifier).png")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return Bundle(for: SnapshotBundleToken.self).url(forResource: identifier, withExtension: "png")
    }

    private static func write(_ image: UIImage, to url: URL) throws {
        guard let data = image.pngData() else {
            throw SnapshotError.pngEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }
}

/// 테스트 번들을 찾기 위한 표식. 기준 이미지가 이 번들의 리소스로 들어 있다.
private final class SnapshotBundleToken {}
