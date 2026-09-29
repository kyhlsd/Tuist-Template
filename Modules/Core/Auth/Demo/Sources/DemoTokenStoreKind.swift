//
//  DemoTokenStoreKind.swift
//  AuthDemo
//

import Auth
import AuthTesting

/// 화면의 저장소 선택기 항목. 바꾸면 `AuthSession` 을 새로 만든다.
enum DemoTokenStoreKind: CaseIterable, Hashable {
    /// 실제 Keychain. 재실행 뒤에도 토큰이 남는다.
    case keychain
    /// 프로세스 메모리. Keychain 을 쓸 수 없을 때(예: -34018) 흐름을 확인하는 폴백이다.
    case inMemory
    /// 저장·삭제가 항상 실패한다. 저장 실패 경로를 확인한다.
    case failing

    func makeStore() -> any TokenStore {
        switch self {
        case .keychain:
            KeychainTokenStore(service: StoreConstants.keychainService)
        case .inMemory:
            InMemoryTokenStore()
        case .failing:
            FailingTokenStore(tokens: nil, saveFailures: StoreConstants.alwaysFail, failsClear: true)
        }
    }
}

private enum StoreConstants {
    /// 앱의 Keychain 항목과 섞이지 않도록 데모 전용 service 를 쓴다.
    static let keychainService = "auth.demo.tokens"
    /// `FailingTokenStore` 가 저장에 실패할 횟수. 사실상 매번 실패한다.
    static let alwaysFail = Int.max
}
