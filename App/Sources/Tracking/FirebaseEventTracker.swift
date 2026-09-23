//
//  FirebaseEventTracker.swift
//  TuistApp
//

import FirebaseAnalytics
import Tracking

/// 이벤트를 Firebase Analytics 로 보낸다.
///
/// `Analytics` 는 클래스 메서드만 쓰므로 저장할 인스턴스가 없다. 만들기만 해서는 Firebase 를 부르지 않는다.
/// Firebase 를 초기화한 뒤에만 쓴다(`FirebaseBootstrap`).
struct FirebaseEventTracker: EventTracking {
    func track(_ event: TrackingEvent) {
        Analytics.logEvent(event.name, parameters: Self.parameters(for: event))
    }

    /// Analytics 가 받는 값(문자열, 숫자)으로 바꾼다. 파라미터가 없으면 `nil` 을 넘긴다.
    static func parameters(for event: TrackingEvent) -> [String: Any]? {
        guard !event.parameters.isEmpty else {
            return nil
        }
        return event.parameters.mapValues { value -> Any in
            switch value {
            case let .string(string):
                string
            case let .int(int):
                int
            case let .double(double):
                double
            }
        }
    }
}
