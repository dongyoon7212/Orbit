// DailyHoursView.swift
// Orbit — 온보딩 4단계: 하루 공부 시간 선택

import SwiftUI

struct DailyHoursView: View {
    @Bindable var viewModel: OnboardingViewModel

    private func minuteLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(remaining)분"
    }

    var body: some View {
        OnboardingLayout(viewModel: viewModel, content: {
            VStack(spacing: 40) {
                // 현재 선택 표시
                VStack(spacing: 8) {
                    Text(minuteLabel(viewModel.dailyStudyMinutes))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: viewModel.dailyStudyMinutes)

                    Text("하루 공부 시간")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity)

                // 시간 선택 그리드
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(viewModel.minuteOptions, id: \.self) { minutes in
                        let isSelected = viewModel.dailyStudyMinutes == minutes

                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.dailyStudyMinutes = minutes
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(minuteLabel(minutes))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(isSelected ? .black : .white)

                                // 세션 수 힌트
                                Text("세션 \(max(1, minutes / 25))개")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                        .scaleEffect(isSelected ? 1.03 : 1.0)
                        .animation(.spring(response: 0.25), value: isSelected)
                    }
                }
                .padding(.horizontal, 24)

                // 안내 메시지
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                    Text("포모도로 25분 세션 기준으로 구성됩니다")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 24)
            }
        }, nextButtonTitle: "공부 시간 설정 완료", onNext: viewModel.goNext)
    }
}
