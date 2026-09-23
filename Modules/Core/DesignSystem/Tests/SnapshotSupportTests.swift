//
//  SnapshotSupportTests.swift
//  DesignSystemTests
//

import SwiftUI
import Testing

/// 빈 렌더는 CI의 느린 러너에서만 나타나 스냅샷 테스트로는 분기를 밟을 수 없다.
/// 판정 함수와 비교 분기, 렌더 경로를 직접 검증한다.
@Suite("스냅샷 지원")
@MainActor
struct SnapshotSupportTests {
    // MARK: - 빈 렌더 판정

    @Test
    func isBlank_모든픽셀투명_참() {
        let bytes = [UInt8](repeating: 0, count: Layout.pixelCount * 4)

        #expect(Snapshot.isBlank(bytes))
    }

    /// 색 없이 알파만 남은 픽셀 하나도 그려진 것으로 본다.
    @Test
    func isBlank_알파있는픽셀하나_거짓() {
        var bytes = [UInt8](repeating: 0, count: Layout.pixelCount * 4)
        bytes[bytes.count - 1] = 1

        #expect(!Snapshot.isBlank(bytes))
    }

    // MARK: - 비교 분기

    @Test
    func mismatch_렌더만비어있음_빈렌더메시지() throws {
        let blank = try render(Color.clear)
        let reference = try render(Color.red)

        let message = Snapshot.mismatch(between: blank, and: reference, identifier: "blank") { _ in Layout.failureURL }

        #expect(message?.hasPrefix(Snapshot.blankRenderMessagePrefix) == true)
    }

    /// 의도적으로 투명한 뷰는 기준 이미지도 투명하므로 빈 렌더로 보지 않는다.
    @Test
    func mismatch_렌더와기준모두비어있음_통과() throws {
        let blank = try render(Color.clear)

        let message = Snapshot.mismatch(between: blank, and: blank, identifier: "clear") { _ in Layout.failureURL }

        #expect(message == nil)
    }

    // MARK: - 렌더 경로

    /// 비트맵 컨텍스트는 원점이 왼쪽 아래라, 뒤집힘과 배율을 한 번에 고정한다.
    @Test
    func render_위빨강아래파랑_픽셀크기와방향유지() throws {
        let view = VStack(spacing: 0) {
            Color.red
            Color.blue
        }
        let image = try #require(Snapshot.render(view, size: Layout.splitSize)?.cgImage)
        let bytes = try #require(Snapshot.pixelBytes(of: image))

        // 기본 배율 2 → 2x4 pt 가 4x8 px 이 된다. 첫 행(위)은 빨강, 마지막 행(아래)은 파랑이어야 한다.
        #expect(image.width == Layout.splitPixelWidth && image.height == Layout.splitPixelHeight)
        #expect(bytes[0] > bytes[2])
        #expect(bytes[bytes.count - 2] > bytes[bytes.count - 4])
    }

    private func render(_ view: some View) throws -> UIImage {
        try #require(Snapshot.render(view, size: Layout.squareSize))
    }
}

private enum Layout {
    static let pixelCount = 16
    static let squareSize = CGSize(width: pointLength, height: pointLength)
    static let splitSize = CGSize(width: halfLength, height: pointLength)
    static let splitPixelWidth = 4
    static let splitPixelHeight = 8
    private static let pointLength: CGFloat = 4
    private static let halfLength: CGFloat = 2
    static let failureURL = URL(fileURLWithPath: "/dev/null")
}
