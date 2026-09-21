//
//  Route.swift
//  Navigation
//

/// `Routing` 으로 이동을 요청할 수 있는 값.
///
/// 각 피처 Interface 의 Route(예: `HomeRoute`)가 채택한다. 아무 `Hashable` 이나
/// push 하는 실수를 컴파일 타임에 막는 마커 프로토콜이다.
///
/// 딥링크 파서처럼 격리되지 않은 문맥에서도 쓰는 순수 값이므로 `nonisolated` 로 선언한다.
public nonisolated protocol Route: Hashable, Sendable {}
