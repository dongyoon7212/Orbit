// PlanGeneratingView.swift
// Orbit — 온보딩 6단계: AI 플랜 생성 로딩 화면

import SwiftUI
import SwiftData

struct PlanGeneratingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: OnboardingViewModel

    @State private var rocketOffset: CGFloat = 0
    @State private var rocketRotation: Double = 0
    @State private var glowOpacity: Double = 0.4

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 로켓 애니메이션
            ZStack {
                // 글로우 효과
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(glowOpacity), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Text("🚀")
                    .font(.system(size: 64))
                    .rotationEffect(.degrees(rocketRotation))
                    .offset(y: rocketOffset)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    rocketOffset = -20
                }
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    rocketRotation = 8
                    glowOpacity = 0.8
                }
            }

            Spacer().frame(height: 48)

            // 타이틀
            Text(viewModel.currentStep.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            // 진행 메시지
            Text(viewModel.planGenerationMessage)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut, value: viewModel.planGenerationMessage)

            Spacer().frame(height: 48)

            // 진행률 바
            VStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.planGenerationProgress, height: 6)
                            .animation(.easeInOut(duration: 0.5), value: viewModel.planGenerationProgress)
                    }
                }
                .frame(height: 6)

                Text("\(Int(viewModel.planGenerationProgress * 100))%")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .animation(.easeInOut, value: viewModel.planGenerationProgress)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .task {
            await viewModel.generatePlan(modelContext: modelContext)
        }
    }
}
