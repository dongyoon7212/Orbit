// StudyDaysView.swift
// Orbit — 온보딩 3단계: 공부 요일 선택

import SwiftUI

struct StudyDaysView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    private var weeklyTimeLabel: String {
        let totalMinutes = viewModel.selectedDays.count * viewModel.dailyStudyMinutes
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 { return "총 \(hours)시간/주" }
        return "총 \(hours)시간 \(minutes)분/주"
    }
    private let weekdayColors: [Color] = [
        .red.opacity(0.8), .white, .white, .white, .white, .white, .blue.opacity(0.8)
    ]

    var body: some View {
        OnboardingLayout(viewModel: viewModel, content: {
            VStack(spacing: 40) {
                // 요일 선택 버튼들
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        let isSelected = viewModel.selectedDays.contains(day)

                        Button(action: { viewModel.toggleDay(day) }) {
                            VStack(spacing: 8) {
                                Text(weekdays[day])
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? .black : weekdayColors[day])

                                Circle()
                                    .fill(isSelected ? Color.white : Color.clear)
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.25), value: isSelected)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)

                // 선택 요약
                VStack(spacing: 8) {
                    Text("주 \(viewModel.selectedDays.count)일 공부")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text(weeklyTimeLabel)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
            }
        }, nextButtonTitle: "요일 선택 완료", onNext: viewModel.goNext)
    }
}
