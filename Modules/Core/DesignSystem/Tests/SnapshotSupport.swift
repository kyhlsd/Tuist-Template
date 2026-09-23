//
//  SnapshotSupport.swift
//  DesignSystemTests
//
//  ⚠️ 테스트 타깃에 포함한다.
//

@testable import DesignSystem
import SwiftUI
import Testing
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
    ///
    /// `ImageRenderer.uiImage` 대신 직접 만든 비트맵 컨텍스트에 `render(rasterizationScale:renderer:)`로 그린다.
    /// `uiImage`가 어떤 래스터라이저를 쓰는지는 문서에 없고, 느린 CI 러너에서 크기만 맞고
    /// 픽셀이 전부 투명한 이미지를 돌려준 적이 있다(`docs/plans/2026-09-23-snapshot-blank-render.md`).
    /// `render`는 문서상 Core Graphics 그리기 명령으로 호출자의 컨텍스트에 그린다.
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
        // 뷰가 안전영역을 참조하지 않도록 명시적 크기를 고정한다.
        renderer.proposedSize = ProposedViewSize(size)

        guard let context = bitmapContext(
            width: Int((size.width * scale).rounded()),
            height: Int((size.height * scale).rounded())
        ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)

        renderer.render(rasterizationScale: scale) { _, draw in
            draw(context)
        }

        return context.makeImage().map { UIImage(cgImage: $0, scale: scale, orientation: .up) }
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

        return mismatch(between: rendered, and: reference, identifier: identifier) { rendered in
            recordFailure(rendered, identifier: identifier, recordURL: recordURL)
        }
    }

    /// 빈 렌더 실패 메시지의 머리말. 테스트가 분기를 구분하는 데 쓴다.
    static let blankRenderMessagePrefix = "렌더러가 빈(완전히 투명한) 이미지를 반환했습니다"

    /// 기준 이미지와 다르면 실패 사유를, 같으면 `nil`을 돌려준다.
    ///
    /// - Parameter recordFailure: 실패한 렌더를 남기고 그 위치를 돌려준다. 테스트는 디스크에 쓰지 않는 대역을 넘긴다.
    static func mismatch(
        between rendered: UIImage,
        and reference: UIImage,
        identifier: String,
        recordFailure: (UIImage) -> URL
    ) -> String? {
        // 빈 렌더를 외형 변화와 구분한다. 차이 비율만 보면 "기준 이미지의 채널 평균"이 찍혀
        // 레이아웃이 바뀐 것처럼 보인다. 기준 이미지도 비어 있으면 의도한 투명 뷰이므로 일반 비교로 넘긴다.
        if isBlank(rendered), !isBlank(reference) {
            let failureURL = recordFailure(rendered)
            return "\(blankRenderMessagePrefix): \(identifier). 실제 결과: \(failureURL.path)"
        }

        let difference = pixelDifference(between: rendered, and: reference)

        if difference <= tolerance {
            return nil
        }

        let failureURL = recordFailure(rendered)
        let percentage = String(format: "%.2f", difference * 100)
        return "외형이 달라졌습니다: \(identifier) (차이 \(percentage)%). 실제 결과: \(failureURL.path)"
    }

    /// 실패한 실제 결과를 눈으로 비교할 수 있게 남긴다.
    ///
    /// 소스 옆 `__Failures__`는 로컬과 CI 아티팩트용이고, 첨부는 `.xcresult` 안에서 바로 보기 위한 것이다.
    /// 성공한 테스트의 첨부를 지우는 API가 없으므로 실패 경로에서만 기록한다.
    private static func recordFailure(_ rendered: UIImage, identifier: String, recordURL: URL) -> URL {
        Attachment.record(rendered, named: "\(identifier).png", as: .png)

        let failureURL = recordURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Failures__/\(identifier).png")
        // 파일은 보조 수단이다. 쓰지 못해도 첨부와 실패 메시지는 남으므로 무시한다.
        try? write(rendered, to: failureURL)
        return failureURL
    }

    /// 모든 픽셀이 투명한지. 비트맵을 읽을 수 없으면 판정하지 않고 `false`를 돌려준다(비교가 대신 실패시킨다).
    private static func isBlank(_ image: UIImage) -> Bool {
        guard let bytes = image.cgImage.flatMap(pixelBytes(of:)) else { return false }
        return isBlank(bytes)
    }

    /// 모든 픽셀의 알파가 0인지. `pixelBytes(of:)`의 RGBA 바이트를 받는다.
    static func isBlank(_ rgbaBytes: [UInt8]) -> Bool {
        let alphaIndices = stride(from: PixelLayout.alphaOffset, to: rgbaBytes.count, by: PixelLayout.bytesPerPixel)
        return !alphaIndices.contains { rgbaBytes[$0] != 0 }
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

    static func pixelBytes(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height

        guard let context = bitmapContext(width: width, height: height) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // `data`는 컨텍스트가 소유한 메모리다. 복사가 끝날 때까지 컨텍스트가 해제되지 않게 붙잡는다.
        return withExtendedLifetime(context) {
            guard let data = context.data else {
                return nil
            }
            let count = context.bytesPerRow * height
            return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count))
        }
    }

    /// 렌더링과 비교가 같이 쓰는 RGBA8(premultipliedLast) 비트맵 컨텍스트. 투명으로 초기화되어 있다.
    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: PixelLayout.bitsPerComponent,
            bytesPerRow: width * PixelLayout.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        // 시스템이 할당한 메모리가 0으로 채워진다는 보장이 문서에 없어 직접 비운다.
        context?.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return context
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

/// 비교와 렌더링이 쓰는 RGBA8(premultipliedLast) 픽셀 배치.
private enum PixelLayout {
    static let bitsPerComponent = 8
    static let bytesPerPixel = 4
    /// 픽셀 안에서 알파 채널의 위치(R, G, B, A 순서).
    static let alphaOffset = 3
}
