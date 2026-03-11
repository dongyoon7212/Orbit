// ExamDateView.swift
// Orbit — 온보딩 2단계: 시험일 설정

import SwiftUI

struct ExamDateView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var dDayText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: viewModel.examDate).day ?? 0
        if days > 0 { return "D-\(days)" }
        if days == 0 { return "D-Day" }
        return "시험일이 이미 지났습니다"
    }

    private var isValidDate: Bool {
        viewModel.examDate > Date()
    }

    var body: some View {
        OnboardingLayout(viewModel: viewModel, content: {
            VStack(spacing: 32) {
                // D-Day 뱃지
                HStack {
                    Spacer()
                    Text(dDayText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(isValidDate ? .white : Color.red.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(isValidDate ? Color.white.opacity(0.15) : Color.red.opacity(0.2))
                        )
                    Spacer()
                }
                .padding(.top, 32)

                // 날짜 피커
                DatePicker(
                    "",
                    selection: $viewModel.examDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .colorScheme(.dark)
                .tint(.white)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.07))
                )
                .padding(.horizontal, 24)

                if !isValidDate {
                    Text("오늘 이후의 날짜를 선택해 주세요")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.red.opacity(0.8))
                }
            }
        }, nextButtonTitle: "시험일 설정 완료", onNext: viewModel.goNext)
    }
}
