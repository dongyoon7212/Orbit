// OrbitApp.swift
// Orbit
//
// 앱 진입점 — SwiftData 컨테이너 설정 + 온보딩/홈 라우팅

import SwiftUI
import SwiftData

@main
struct OrbitApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserMission.self,
            PlanetSubject.self,
            ExplorationChapter.self,
            FocusSession.self,
            MissedDayLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("SwiftData ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
