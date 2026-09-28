//
//  SettingKey.swift
//  Persistence
//

/// 값 타입과 기본값을 함께 가진 설정 키.
///
/// 키 이름은 쓰는 쪽(Data)의 `private enum` 에 모아 선언한다. 저장소가 붙이는 접두사는 포함하지 않는다.
public struct SettingKey<Value: Codable & Sendable>: Sendable {
    public let name: String
    /// 저장된 값이 없을 때 돌려주는 값.
    public let defaultValue: Value

    public init(name: String, defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}
