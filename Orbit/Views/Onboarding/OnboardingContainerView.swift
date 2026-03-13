// OnboardingContainerView.swift
// Orbit
//
// 온보딩 전체 컨테이너 — 6단계 화면 전환 관리

import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // 우주 배경
            SpaceBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 진행 바 (플랜 확인 단계 포함하여 모든 단계 표시)
                OnboardingProgressBar(
                    currentStep: viewModel.currentStep.rawValue,
                    totalSteps: OnboardingViewModel.Step.allCases.count - 1
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // 단계별 화면
                Group {
                    switch viewModel.currentStep {
                    case .certificationSelect:
                        CertificationSelectView(viewModel: viewModel)
                    case .examDate:
                        ExamDateView(viewModel: viewModel)
                    case .studyDays:
                        StudyDaysView(viewModel: viewModel)
                    case .dailyHours:
                        DailyHoursView(viewModel: viewModel)
                    case .experienceLevel:
                        ExperienceLevelView(viewModel: viewModel)
                    case .planConfirm:
                        PlanConfirmView(viewModel: viewModel)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .task {
            await viewModel.loadCertifications()
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - 진행 바

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - 우주 배경

struct SpaceBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.04, blue: 0.15),
                Color(red: 0.08, green: 0.05, blue: 0.22),
                Color(red: 0.02, green: 0.02, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            // 별 효과 (정적)
            StarsOverlayView()
        }
    }
}

struct StarsOverlayView: View {
    // 시드 기반 고정 위치 별들
    private let stars: [(x: Double, y: Double, size: Double, opacity: Double)] = {
        var result: [(Double, Double, Double, Double)] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<80 {
            let x = Double.random(in: 0...1, using: &rng)
            let y = Double.random(in: 0...1, using: &rng)
            let size = Double.random(in: 1...3, using: &rng)
            let opacity = Double.random(in: 0.3...1.0, using: &rng)
            result.append((x, y, size, opacity))
        }
        return result
    }()

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(stars[i].opacity))
                    .frame(width: stars[i].size, height: stars[i].size)
                    .position(
                        x: stars[i].x * geometry.size.width,
                        y: stars[i].y * geometry.size.height
                    )
            }
        }
    }
}

// MARK: - 공통 온보딩 레이아웃

struct OnboardingLayout<Content: View>: View {
    let viewModel: OnboardingViewModel
    let content: () -> Content
    var showBackButton: Bool = true
    var nextButtonTitle: String = "다음"
    var onNext: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 뒤로가기 버튼
            if showBackButton && viewModel.currentStep.rawValue > 0 {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                }
                .padding(.top, 8)
            } else {
                Spacer().frame(height: 52)
            }

            // 타이틀
            Text(viewModel.currentStep.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .padding(.horizontal, 28)
                .padding(.top, 24)

            // 콘텐츠
            content()

            Spacer()

            // 다음 버튼
            if let onNext {
                Button(action: onNext) {
                    Text(nextButtonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(viewModel.canGoNext ? Color.white : Color.white.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.canGoNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
