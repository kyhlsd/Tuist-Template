//
//  PushToken.swift
//  TuistApp
//

import Foundation

/// APNs 디바이스 토큰의 문자열 표현.
///
/// 서버는 보통 토큰을 소문자 16진수 문자열로 받는다. `Data.description` 은 형식이 보장되지 않으므로 쓰지 않는다.
enum PushToken {
    static func hexString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: Format.byte, $0) }.joined()
    }

    private enum Format {
        static let byte = "%02x"
    }
}
