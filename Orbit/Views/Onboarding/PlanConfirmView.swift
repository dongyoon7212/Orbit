// PlanConfirmView.swift
// Orbit
//
// 온보딩 6단계: 알고리즘이 계산한 플랜 요약 확인 → 탐사 시작

import SwiftUI
import SwiftData

struct PlanConfirmView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let summary = viewModel.planSummary {
                confirmView(summary: summary)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            }
        }
    }

    // MARK: - 로딩

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("플랜 계산 중...")
                .foregroundStyle(.white.opacity(0.7))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 플랜 확인

    private func confirmView(summary: StudyPlanAlgorithm.PlanSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 전체 요약 카드
                overallSummaryCard(summary: summary)

                // 과목별 요약
                VStack(alignment: .leading, spacing: 12) {
                    Text("과목별 탐사 일정")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(summary.subjectSummaries, id: \.subjectName) { subjectSummary in
                        subjectRow(subjectSummary)
                    }
                }

                // 복습 주간 안내
                if let reviewStart = summary.reviewWeekStart {
                    reviewWeekCard(reviewStart: reviewStart)
                }

                // 탐사 시작 버튼
                Button {
                    Task {
                        await viewModel.confirmAndSave(modelContext: modelContext)
                    }
                } label: {
                    HStack {
                        Text("🚀 탐사 시작!")
                            .font(.headline)
                            .fontWeight(.bold)
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#4B70DD"), Color(hex: "#7B3FE4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(viewModel.isLoading)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 전체 요약 카드

    private func overallSummaryCard(summary: StudyPlanAlgorithm.PlanSummary) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                statItem(
                    value: "\(summary.totalStudyDays)일",
                    label: "총 공부일"
                )
                Divider()
                    .frame(height: 40)
                    .overlay(.white.opacity(0.3))
                statItem(
                    value: "\(summary.totalChapters)개",
                    label: "전체 챕터"
                )
                Divider()
                    .frame(height: 40)
                    .overlay(.white.opacity(0.3))
                statItem(
                    value: "\(Int(summary.totalEstimatedHours))h",
                    label: "예상 시간"
                )
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 과목별 행

    private func subjectRow(_ subjectSummary: StudyPlanAlgorithm.SubjectSummary) -> some View {
        HStack(spacing: 12) {
            // 날짜 범위
            VStack(alignment: .leading, spacing: 2) {
                Text(subjectSummary.subjectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                if let first = subjectSummary.firstStudyDate,
                   let last = subjectSummary.lastStudyDate {
                    Text("\(formatDate(first)) ~ \(formatDate(last))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(subjectSummary.chapterCount)챕터")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("\(Int(subjectSummary.estimatedHours))h")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 복습 주간 카드

    private func reviewWeekCard(reviewStart: Date) -> some View {
        HStack(spacing: 12) {
            Text("🔁")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("복습 주간")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("\(formatDate(reviewStart))부터 시험 전까지 전체 복습")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "#4B70DD").opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "#4B70DD").opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 오류 화면

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text("⚠️")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .font(.subheadline)
            Button("다시 시도") {
                Task { await viewModel.computePlanPreview() }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - 날짜 포맷

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}


