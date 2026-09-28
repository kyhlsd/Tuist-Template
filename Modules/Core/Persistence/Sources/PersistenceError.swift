//
//  PersistenceError.swift
//  Persistence
//

/// 기기 안 저장소의 실패.
///
/// 원인 에러는 `Equatable` 을 지키기 위해 담지 않는다. 보고는 case 이름으로 한다.
public enum PersistenceError: Error, Equatable, Sendable {
    /// 값을 저장 형식으로 바꿀 수 없다.
    case encodingFailed
    /// 저장된 값을 요청한 타입으로 해석할 수 없다.
    case decodingFailed
    /// 저장소를 열 수 없다.
    case storeUnavailable
    /// 열린 저장소에서 읽기·쓰기가 실패했다.
    case operationFailed
}
