// ChapterDetailView.swift
// Orbit
//
// 챕터 시작 화면: Claude 코칭 멘트 + 타이머 시작 버튼 + 챕터 완료 버튼

import SwiftUI
import SwiftData

struct ChapterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let chapter: ExplorationChapter
    let missionName: String

    @State private var pomodoroVM = PomodoroViewModel()
    @State private var showTimer = false
    @State private var showCompletion = false

    var body: some View {
        ZStack {
            SpaceBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 닫기
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    Spacer()

                    // 중요도 배지
                    ImportanceBadge(importance: chapter.importance)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 28) {

                        // 챕터 헤더
                        chapterHeader

                        // Claude 코칭 멘트
                        coachingSection

                        // 예상 시간 & 뽀모도로 수
                        statsRow

                        Spacer(minLength: 20)

                        // 액션 버튼들
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 48)
                }
            }
        }
        .task {
            pomodoroVM.setup(chapter: chapter)
            await loadCoachingMessage()
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerView(
                pomodoroVM: pomodoroVM,
                chapter: chapter,
                onComplete: {
                    showTimer = false
                    showCompletion = true
                },
                onDismiss: {
                    showTimer = false
                }
            )
        }
        .fullScreenCover(isPresented: $showCompletion) {
            ChapterCompletionView(
                chapter: chapter,
                studiedSeconds: pomodoroVM.totalStudiedSeconds,
                onDone: {
                    completeChapter()
                    showCompletion = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - 챕터 헤더

    private var chapterHeader: some View {
        VStack(spacing: 12) {
            // 행성 아이콘
            if let subject = chapter.subject {
                ZStack {
                    Circle()
                        .fill(Color(hex: subject.planetType.color).opacity(0.2))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color(hex: subject.planetType.color).opacity(0.4))
                        .frame(width: 56, height: 56)
                    Text(subject.planetType.emoji)
                        .font(.system(size: 28))
                }

                Text(subject.name)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(chapter.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - 코칭 멘트 섹션

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI 코칭", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )

                if pomodoroVM.isLoadingCoaching {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                            .scaleEffect(0.8)
                        Text("코칭 멘트 불러오는 중...")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(20)
                } else if pomodoroVM.coachingMessage.isEmpty {
                    Text("집중해서 학습해보세요! 💪")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(20)
                } else {
                    Text(pomodoroVM.coachingMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(5)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 72)
        }
    }

    // MARK: - 통계 행

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(
                icon: "clock",
                value: "\(chapter.estimatedMinutes)분",
                label: "예상 시간"
            )
            statChip(
                icon: "timer",
                value: "\(pomodoroCount)세트",
                label: "뽀모도로"
            )
            statChip(
                icon: "star.fill",
                value: "\(chapter.importance.stars)★",
                label: "중요도"
            )
        }
    }

    private var pomodoroCount: Int {
        let sets = chapter.estimatedMinutes / 25
        return max(1, sets)
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07)))
    }

    // MARK: - 액션 버튼

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 타이머 시작
            Button {
                showTimer = true
                pomodoroVM.setup(chapter: chapter)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("타이머 시작")
                        .fontWeight(.bold)
                }
                .font(.system(size: 17))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // 타이머 없이 바로 완료
            Button {
                showCompletion = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                    Text("챕터 완료 처리")
                }
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
            }
        }
    }

    // MARK: - 코칭 멘트 로드

    private func loadCoachingMessage() async {
        guard let subject = chapter.subject else { return }
        pomodoroVM.isLoadingCoaching = true
        do {
            let message = try await ClaudeService.shared.generateCoachingMessage(
                chapterTitle: chapter.title,
                subjectName: subject.name,
                certificationName: missionName,
                importanceLevel: chapter.importance
            )
            pomodoroVM.coachingMessage = message
        } catch {
            // 코칭 로드 실패는 비치명적 — 기본 메시지 유지
            pomodoroVM.coachingMessage = ""
        }
        pomodoroVM.isLoadingCoaching = false
    }

    // MARK: - 챕터 완료 처리

    private func completeChapter() {
        withAnimation {
            chapter.isCompleted = true
            chapter.completedAt = Date()

            if let subject = chapter.subject {
                let allDone = subject.chapters.allSatisfy { $0.isCompleted }
                if allDone {
                    subject.isCompleted = true
                    subject.completedAt = Date()
                }
            }
            try? modelContext.save()
        }

        if let identifier = chapter.reminderIdentifier {
            Task { try? await EventKitService.shared.completeReminder(identifier: identifier) }
        }
    }
}
