// HomeView.swift
// Orbit — 홈 화면: 행성(과목) 목록 + 오늘 할일

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserMission.createdAt, order: .reverse) private var missions: [UserMission]

    var activeMission: UserMission? { missions.first(where: { !$0.isCompleted }) }

    var body: some View {
        ZStack {
            SpaceBackgroundView().ignoresSafeArea()

            if let mission = activeMission {
                MissionDashboardView(mission: mission)
            } else {
                EmptyMissionView()
            }
        }
    }
}

// MARK: - 미션 대시보드

struct MissionDashboardView: View {
    let mission: UserMission

    private var todayChapters: [ExplorationChapter] {
        let today = Calendar.current.startOfDay(for: Date())
        return mission.subjects.flatMap { $0.chapters }.filter { chapter in
            guard let planned = chapter.plannedDate else { return false }
            return Calendar.current.isDate(planned, inSameDayAs: today) && !chapter.isCompleted
        }
    }

    private var dDayText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: mission.examDate).day ?? 0
        if days > 0 { return "D-\(days)" }
        if days == 0 { return "D-Day" }
        return "시험 완료"
    }

    private var overallProgress: Double {
        let allChapters = mission.subjects.flatMap { $0.chapters }
        guard !allChapters.isEmpty else { return 0 }
        let completed = allChapters.filter { $0.isCompleted }.count
        return Double(completed) / Double(allChapters.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 헤더
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("탐사 미션")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(mission.certificationName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // D-Day 뱃지
                    Text(dDayText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                // 전체 진행률
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("전체 탐사 진행률")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(overallProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * overallProgress, height: 6)
                                .animation(.easeInOut, value: overallProgress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 24)

                // 오늘 할일
                if !todayChapters.isEmpty {
                    TodayChaptersSection(chapters: todayChapters)
                }

                // 행성(과목) 목록
                PlanetsSection(subjects: mission.subjects.sorted { $0.order < $1.order })
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 오늘 할일 섹션

struct TodayChaptersSection: View {
    let chapters: [ExplorationChapter]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "오늘의 탐사", icon: "calendar.badge.clock")
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chapters) { chapter in
                        TodayChapterCard(chapter: chapter)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct TodayChapterCard: View {
    @Environment(\.modelContext) private var modelContext
    let chapter: ExplorationChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ImportanceBadge(importance: chapter.importance)
                Spacer()
                Text("\(chapter.estimatedMinutes)분")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(chapter.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 완료 버튼
            Button(action: completeChapter) {
                Label("완료", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
            }
        }
        .padding(16)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func completeChapter() {
        withAnimation {
            chapter.isCompleted = true
            chapter.completedAt = Date()

            // 상위 과목 완료 여부 확인
            if let subject = chapter.subject {
                let allDone = subject.chapters.allSatisfy { $0.isCompleted }
                if allDone {
                    subject.isCompleted = true
                    subject.completedAt = Date()
                }
            }

            try? modelContext.save()
        }

        // EventKit 완료 처리
        if let identifier = chapter.reminderIdentifier {
            Task {
                try? await EventKitService.shared.completeReminder(identifier: identifier)
            }
        }
    }
}

// MARK: - 행성 섹션

struct PlanetsSection: View {
    let subjects: [PlanetSubject]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "탐사 행성", icon: "globe")
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(subjects) { subject in
                    PlanetCard(subject: subject)
                        .padding(.horizontal, 24)
                }
            }
        }
    }
}

struct PlanetCard: View {
    let subject: PlanetSubject

    private var planetColor: Color {
        Color(hex: subject.planetType.color)
    }

    var body: some View {
        HStack(spacing: 16) {
            // 행성 아이콘
            ZStack {
                Circle()
                    .fill(planetColor.opacity(0.3))
                    .frame(width: 52, height: 52)
                Circle()
                    .fill(planetColor.opacity(0.6))
                    .frame(width: 36, height: 36)
                Text(planetEmoji(subject.planetType))
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(subject.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if subject.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Text("\(Int(subject.completionRate * 100))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                // 진행 바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(planetColor)
                            .frame(width: geo.size.width * subject.completionRate, height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(subject.chapters.filter { $0.isCompleted }.count)/\(subject.chapters.count) 챕터 완료")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
        )
        .opacity(subject.isCompleted ? 0.7 : 1.0)
    }

    private func planetEmoji(_ planet: PlanetType) -> String {
        switch planet {
        case .mercury: return "⚫️"
        case .venus:   return "🟡"
        case .mars:    return "🔴"
        case .jupiter: return "🟠"
        case .saturn:  return "🪐"
        case .uranus:  return "🔵"
        case .neptune: return "💙"
        }
    }
}

// MARK: - 미션 없는 빈 상태

struct EmptyMissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("🚀")
                .font(.system(size: 72))

            Text("아직 탐사 미션이 없습니다")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("자격증을 선택하고\n우주 탐사를 시작해 보세요!")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - 공통 컴포넌트

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
    }
}

struct ImportanceBadge: View {
    let importance: ImportanceLevel

    private var color: Color {
        switch importance {
        case .high:   return .red.opacity(0.8)
        case .medium: return .orange.opacity(0.8)
        case .low:    return .gray.opacity(0.8)
        }
    }

    var body: some View {
        Text(importance.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }
}


