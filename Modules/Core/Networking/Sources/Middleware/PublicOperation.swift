//
//  PublicOperation.swift
//  Networking
//

/// 토큰 없이 호출하는 operation.
///
/// 값은 `OpenAPI/openapi.yaml` 의 operationId 와 같아야 한다. 명세에서 `security: []` 인
/// operation 을 추가하면 여기도 고친다. 빠지면 로그인 실패(401)가 토큰 갱신을 일으킨다.
enum PublicOperation {
    static let ids: Set<String> = [
        "login",
        "refreshToken",
    ]
}
