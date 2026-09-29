//
//  PersistenceDemoView.swift
//  PersistenceDemo
//

import Persistence
import SwiftUI

/// 저장 위치, 실행 횟수, 캐시 항목, 마지막 에러를 보여 주고 조작하는 화면.
struct PersistenceDemoView: View {
    let model: PersistenceDemoModel

    var body: some View {
        NavigationStack {
            Form {
                Section("저장 위치") {
                    LabeledContent("SwiftData", value: model.onDiskError == nil ? "onDisk" : "inMemory (폴백)")
                    if let onDiskError = model.onDiskError {
                        LabeledContent("onDisk 실패 원인", value: String(describing: onDiskError))
                    }
                }
                Section("실행 횟수 (UserDefaults)") {
                    LabeledContent("launchCount", value: "\(model.launchCount)")
                    Button("실행 횟수 초기화", role: .destructive) {
                        model.resetLaunchCount()
                    }
                }
                Section("캐시 항목 \(model.records.count)개 (SwiftData)") {
                    ForEach(model.records, id: \.id) { record in
                        LabeledContent(record.title, value: record.id)
                    }
                    Button("샘플로 교체 (중복 id 포함)") {
                        Task { await model.replaceWithSamples() }
                    }
                    Button("비우기", role: .destructive) {
                        Task { await model.removeAll() }
                    }
                }
                Section("마지막 에러") {
                    Text(model.lastError.map { String(describing: $0) } ?? "없음")
                }
            }
            .navigationTitle("Persistence")
            .task { await model.reload() }
        }
    }
}
