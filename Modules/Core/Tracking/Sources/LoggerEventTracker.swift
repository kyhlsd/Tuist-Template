//
//  LoggerEventTracker.swift
//  Tracking
//

import os

/// 이벤트를 `os.Logger` 로만 남긴다.
///
/// 전송 수단을 쓰지 않을 때(Debug, 설정 파일 없음, 데모 앱, 프리뷰) 쓴다. 무엇이 기록될지 Console 에서 확인할 수 있다.
/// 이벤트 이름은 코드의 상수라 공개로, 파라미터는 사용자 값이 들어갈 수 있어 비공개로 남긴다.
public struct LoggerEventTracker: EventTracking {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    /// `"이벤트: screen_view {count=3, name=home}"` 한 줄로 남긴다. 두 조각의 공개 범위가 달라 따로 보간한다.
    public func track(_ event: TrackingEvent) {
        let name = Self.message(forName: event.name)
        let parameters = Self.message(forParameters: event.parameters)
        logger.info("\(name, privacy: .public) \(parameters, privacy: .private)")
    }

    /// `"이벤트: screen_view"` 형태. 로그 출력은 테스트에서 읽을 수 없으므로 문구만 분리해 테스트한다.
    static func message(forName name: String) -> String {
        "\(Text.prefix)\(name)"
    }

    /// `"{count=3, name=home}"` 형태. 키 순서로 정렬하고, 없으면 `"{}"` 다.
    static func message(forParameters parameters: [String: TrackingValue]) -> String {
        let pairs = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(description(of: $0.value))" }
        return "{\(pairs.joined(separator: Text.separator))}"
    }

    private static func description(of value: TrackingValue) -> String {
        switch value {
        case let .string(string):
            string
        case let .int(int):
            String(int)
        case let .double(double):
            String(double)
        }
    }
}

private enum Text {
    static let prefix = "이벤트: "
    static let separator = ", "
}
