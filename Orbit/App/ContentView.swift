// ContentView.swift
// Orbit
//
// 루트 뷰 — 온보딩 완료 여부에 따라 온보딩 or 홈으로 라우팅

import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \UserMission.createdAt, order: .reverse) private var missions: [UserMission]

    private var hasActiveMission: Bool {
        missions.contains(where: { !$0.isCompleted })
    }

    var body: some View {
        Group {
            if hasActiveMission {
                HomeView()
            } else {
                OnboardingContainerView()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasActiveMission)
    }
}
