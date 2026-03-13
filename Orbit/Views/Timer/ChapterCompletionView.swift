// ChapterCompletionView.swift
// Orbit
//
// 챕터 완료 후 착륙 축하 화면

import SwiftUI

struct ChapterCompletionView: View {
    let chapter: ExplorationChapter
    let studiedSeconds: Int
    let onDone: () -> Void

    @State private var rocketY: CGFloat = 400
    @State private var rocketOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var particlesVisible: Bool = false
    @State private var scaleEffect: CGFloat = 0.5
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0.8

    private var studiedMinutes: Int { studiedSeconds / 60 }
    private var studiedLabel: String {
        if studiedSeconds == 0 { return "–" }
        if studiedMinutes < 1 { return "\(studiedSeconds)초" }
        return "\(studiedMinutes)분"
    }

    var body: some View {
        ZStack {
            // 배경
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.12),
                    Color(red: 0.08, green: 0.04, blue: 0.22),
                    Color(red: 0.01, green: 0.01, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            StarsOverlayView().ignoresSafeArea()

            // 폭죽 파티클
            if particlesVisible {
                ParticlesBurstView()
            }

            VStack(spacing: 32) {
                Spacer()

                // 착륙 링 + 로켓
                ZStack {
                    // 착륙 링 펄스
                    Circle()
                        .strokeBorder(Color(hex: "#4B70DD").opacity(ringOpacity), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)

                    Circle()
                        .strokeBorder(Color(hex: "#7B3FE4").opacity(ringOpacity * 0.5), lineWidth: 1.5)
                        .frame(width: 170, height: 170)
                        .scaleEffect(ringScale)

                    // 행성 배경
                    if let subject = chapter.subject {
                        Circle()
                            .fill(Color(hex: subject.planetType.color).opacity(0.15))
                            .frame(width: 110, height: 110)
                        Text(subject.planetType.emoji)
                            .font(.system(size: 48))
                    }

                    // 착륙한 로켓 (뒤집혀서 내려옴)
                    Text("🚀")
                        .font(.system(size: 36))
                        .rotationEffect(.degrees(180))
                        .offset(y: rocketY)
                        .opacity(rocketOpacity)
                }
                .frame(height: 200)

                // 완료 텍스트
                VStack(spacing: 10) {
                    Text("착륙 성공!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text(chapter.title)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(contentOpacity)
                .scaleEffect(scaleEffect)

                // 공부 시간 배지
                if studiedSeconds > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .foregroundStyle(.white.opacity(0.6))
                        Text("집중 \(studiedLabel) 공부 완료")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .opacity(contentOpacity)
                }

                Spacer()

                // 확인 버튼
                Button(action: onDone) {
                    Text("계속 탐사하기")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(contentOpacity)
            }
        }
        .onAppear { runEntryAnimation() }
    }

    // MARK: - 입장 애니메이션

    private func runEntryAnimation() {
        // 1) 링 펄스 시작
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.0
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            ringOpacity = 0.2
        }

        // 2) 로켓 착륙 (아래서 위로)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
            rocketY = -8
            rocketOpacity = 1
        }

        // 3) 파티클 + 텍스트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            particlesVisible = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                contentOpacity = 1
                scaleEffect = 1.0
            }
        }
    }
}

// MARK: - 파티클 버스트

struct ParticlesBurstView: View {
    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: Double
        let color: Color
        let size: Double
    }

    private let particles: [Particle] = (0..<20).map { i in
        let colors: [Color] = [.yellow, .orange, .pink, .cyan, .white, .purple]
        return Particle(
            id: i,
            angle: Double(i) / 20.0 * 360.0,
            distance: Double.random(in: 80...160),
            color: colors[i % colors.count],
            size: Double.random(in: 4...9)
        )
    }

    @State private var exploded = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: exploded ? cos(p.angle * .pi / 180) * p.distance : 0,
                        y: exploded ? sin(p.angle * .pi / 180) * p.distance : 0
                    )
                    .opacity(exploded ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                exploded = true
            }
        }
    }
}
