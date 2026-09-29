//
//  AuthDemoView.swift
//  AuthDemo
//

import Auth
import SwiftUI

/// 저장소·서버 모드 선택, 세션 상태·토큰 표시, 로그인·갱신·로그아웃 버튼을 둔 화면.
struct AuthDemoView: View {
    @Bindable var model: AuthDemoModel

    var body: some View {
        NavigationStack {
            Form {
                Section("설정") {
                    Picker("저장소", selection: $model.storeKind) {
                        ForEach(DemoTokenStoreKind.allCases, id: \.self) { kind in
                            Text(title(of: kind)).tag(kind)
                        }
                    }
                    Picker("서버 응답", selection: $model.serverMode) {
                        ForEach(DemoRefreshServer.Mode.allCases, id: \.self) { mode in
                            Text(title(of: mode)).tag(mode)
                        }
                    }
                }
                Section("세션") {
                    LabeledContent("state", value: stateDescription)
                    LabeledContent("access token", value: model.accessToken ?? "없음")
                }
                Section("동작") {
                    Button("로그인") { Task { await model.signIn() } }
                    Button("토큰 읽기") { Task { await model.readToken() } }
                    Button("갱신 (현재 토큰 거절)") { Task { await model.refresh() } }
                        .disabled(model.isRefreshing)
                    Button("로그아웃", role: .destructive) { Task { await model.signOut() } }
                }
                Section("마지막 에러") {
                    Text(model.lastError ?? "없음")
                }
            }
            .navigationTitle("Auth")
            // 저장소를 바꾸면 세션이 새로 만들어지므로 구독도 다시 한다. 뷰가 사라지면 구독이 끊긴다.
            .task(id: model.sessionGeneration) { await model.observeStates() }
        }
    }

    private var stateDescription: String {
        switch model.state {
        case .signedIn: "signedIn"
        case .signedOut: "signedOut"
        case .expired: "expired"
        case nil: "구독 중"
        }
    }

    private func title(of kind: DemoTokenStoreKind) -> String {
        switch kind {
        case .keychain: "Keychain"
        case .inMemory: "InMemory"
        case .failing: "Failing"
        }
    }

    private func title(of mode: DemoRefreshServer.Mode) -> String {
        switch mode {
        case .success: "성공"
        case .expired: "만료 (sessionExpired)"
        case .failure: "실패 (refreshFailed)"
        }
    }
}
