//
//  ItemError.swift
//  Domain
//

/// 항목을 다룰 때 도메인이 구분하는 실패.
///
/// 네트워크·디코딩 같은 구현 세부는 Data 가 이 값으로 변환해서 올린다.
/// Feature 는 이 타입만 보고 화면 상태를 정한다.
public enum ItemError: Error, Equatable, Sendable {
    /// 항목을 가져올 수 없다. (연결 실패, 서버 오류 등)
    case unavailable
    /// 받은 데이터를 해석할 수 없다.
    case invalidData
}
