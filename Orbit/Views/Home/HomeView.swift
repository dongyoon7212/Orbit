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
    @State private var selectedChapter: ExplorationChapter?
    @State private var expandedSubjectId: String?

    private var todayChapters: [ExplorationChapter] {
        let today = Calendar.current.startOfDay(for: Date())
        return mission.subjects
            .sorted { $0.order < $1.order }
            .flatMap { $0.chapters }
            .filter { chapter in
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

    private var dDayColor: Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: mission.examDate).day ?? 0
        if days <= 7 { return .red.opacity(0.8) }
        if days <= 30 { return .orange.opacity(0.8) }
        return .white.opacity(0.2)
    }

    private var overallProgress: Double {
        let all = mission.subjects.flatMap { $0.chapters }
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { $0.isCompleted }.count) / Double(all.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── 헤더 ──────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("탐사 미션")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                        Text(mission.certificationName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(dDayText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(dDayColor))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                // ── 전체 진행률 ─────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("전체 탐사 진행률")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("\(Int(overallProgress * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.12))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#4B70DD"), Color(hex: "#7B3FE4")],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * overallProgress, height: 6)
                                .animation(.easeInOut(duration: 0.6), value: overallProgress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 24)

                // ── 오늘 탐사 ──────────────────────────
                if !todayChapters.isEmpty {
                    TodayChaptersSection(
                        chapters: todayChapters,
                        missionName: mission.certificationName,
                        onSelect: { selectedChapter = $0 }
                    )
                } else {
                    noTodayChaptersRow
                }

                // ── 행성(과목) 목록 ────────────────────
                PlanetsSection(
                    subjects: mission.subjects.sorted { $0.order < $1.order },
                    missionName: mission.certificationName,
                    expandedSubjectId: $expandedSubjectId,
                    onSelectChapter: { selectedChapter = $0 }
                )
            }
            .padding(.bottom, 48)
        }
        .sheet(item: $selectedChapter) { chapter in
            ChapterDetailView(chapter: chapter, missionName: mission.certificationName)
        }
    }

    private var noTodayChaptersRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green.opacity(0.7))
                .font(.title2)
            Text("오늘 일정을 모두 완료했어요 🎉")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 오늘 할일 섹션

struct TodayChaptersSection: View {
    let chapters: [ExplorationChapter]
    let missionName: String
    let onSelect: (ExplorationChapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "오늘의 탐사", icon: "calendar.badge.clock")
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chapters) { chapter in
                        TodayChapterCard(chapter: chapter)
                            .onTapGesture { onSelect(chapter) }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct TodayChapterCard: View {
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

            // 시작 버튼
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                Text("탐사 시작")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white))
        }
        .padding(16)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - 행성 섹션

struct PlanetsSection: View {
    let subjects: [PlanetSubject]
    let missionName: String
    @Binding var expandedSubjectId: String?
    let onSelectChapter: (ExplorationChapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "탐사 행성", icon: "globe")
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(subjects) { subject in
                    PlanetCard(
                        subject: subject,
                        isExpanded: expandedSubjectId == subject.subjectId,
                        onToggle: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                expandedSubjectId = expandedSubjectId == subject.subjectId
                                    ? nil
                                    : subject.subjectId
                            }
                        },
                        onSelectChapter: onSelectChapter
                    )
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

struct PlanetCard: View {
    let subject: PlanetSubject
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelectChapter: (ExplorationChapter) -> Void

    private var planetColor: Color { Color(hex: subject.planetType.color) }

    var body: some View {
        VStack(spacing: 0) {
            // 행성 헤더 행
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    // 행성 아이콘
                    ZStack {
                        Circle()
                            .fill(planetColor.opacity(0.25))
                            .frame(width: 50, height: 50)
                        Circle()
                            .fill(planetColor.opacity(0.5))
                            .frame(width: 34, height: 34)
                        Text(subject.planetType.emoji)
                            .font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(subject.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if subject.isCompleted {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 15))
                            } else {
                                Text("\(Int(subject.completionRate * 100))%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }

                        // 진행 바
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.12))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(planetColor)
                                    .frame(width: geo.size.width * subject.completionRate, height: 4)
                                    .animation(.easeInOut(duration: 0.4), value: subject.completionRate)
                            }
                        }
                        .frame(height: 4)

                        Text("\(subject.chapters.filter { $0.isCompleted }.count)/\(subject.chapters.count) 챕터")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // 챕터 목록 (펼쳐질 때)
            if isExpanded {
                Divider()
                    .overlay(.white.opacity(0.08))
                    .padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(subject.chapters.sorted { $0.order < $1.order }) { chapter in
                        ChapterRow(chapter: chapter)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectChapter(chapter) }

                        if chapter.id != subject.chapters.sorted(by: { $0.order < $1.order }).last?.id {
                            Divider()
                                .overlay(.white.opacity(0.06))
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(subject.isCompleted ? 0.05 : 0.08))
        )
        .opacity(subject.isCompleted ? 0.75 : 1.0)
    }
}

// MARK: - 챕터 행

struct ChapterRow: View {
    let chapter: ExplorationChapter

    var body: some View {
        HStack(spacing: 12) {
            // 완료 아이콘
            ZStack {
                Circle()
                    .fill(chapter.isCompleted ? .green.opacity(0.25) : .white.opacity(0.08))
                    .frame(width: 30, height: 30)
                Image(systemName: chapter.isCompleted ? "checkmark" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chapter.isCompleted ? .green : .white.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.title)
                    .font(.system(size: 14, weight: chapter.isCompleted ? .regular : .medium))
                    .foregroundStyle(chapter.isCompleted ? .white.opacity(0.4) : .white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    // 중요도 별
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(i < chapter.importance.stars
                                    ? .yellow.opacity(0.8)
                                    : .white.opacity(0.12))
                        }
                    }
                    Text("\(chapter.estimatedMinutes)분")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer()

            if !chapter.isCompleted {
                Image(systemName: "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
    }
}

struct ImportanceBadge: View {
    let importance: ImportanceLevel

    private var color: Color {
        switch importance {
        case .high:   return .red.opacity(0.75)
        case .medium: return .orange.opacity(0.75)
        case .low:    return .gray.opacity(0.6)
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
