//
//  AuthError.swift
//  Domain
//

/// 로그인·로그아웃에서 도메인이 구분하는 실패.
///
/// 네트워크·저장소 같은 구현 세부는 Data 가 이 값으로 변환해서 올린다.
/// Feature 는 이 타입만 보고 화면 상태를 정한다.
public enum AuthError: Error, Equatable, Sendable {
    /// 서버가 자격 증명을 거절했다. 입력을 고쳐야 한다.
    case invalidCredentials
    /// 지금은 처리할 수 없다. (연결 실패, 서버 오류, 토큰 보관 실패 등) 다시 시도하면 된다.
    case unavailable
}
