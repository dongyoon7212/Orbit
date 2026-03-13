// ExperienceLevelView.swift
// Orbit — 온보딩 5단계: 경험 수준 선택

import SwiftUI

struct ExperienceLevelView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingLayout(viewModel: viewModel, content: {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    ExperienceLevelCard(
                        level: level,
                        isSelected: viewModel.selectedExperience == level
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedExperience = level
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }, nextButtonTitle: "플랜 확인", onNext: {
            Task {
                // 알고리즘 즉시 실행 후 다음 단계로
                await viewModel.computePlanPreview()
                viewModel.goNext()
            }
        })
    }
}

struct ExperienceLevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool

    private var icon: String {
        switch level {
        case .beginner: return "🚀"
        case .experienced: return "⭐️"
        }
    }

    private var subtitle: String {
        switch level {
        case .beginner: return "처음 도전하는 분 — 기초부터 차근차근 탐사"
        case .experienced: return "관련 경험 있는 분 — 핵심 위주 효율 탐사"
        }
    }

    private var hint: String {
        switch level {
        case .beginner: return "모든 챕터를 균형 있게 배정합니다"
        case .experienced: return "HIGH 중요도 챕터를 집중 배정합니다"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 36))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.2 : 0.07))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(level.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))

                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
