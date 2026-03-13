// TimerView.swift
// Orbit
//
// 뽀모도로 타이머 화면
// 집중: 로켓이 위로 날아오름 / 휴식: 로켓이 천천히 내려옴

import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pomodoroVM: PomodoroViewModel
    let chapter: ExplorationChapter
    let onComplete: () -> Void
    let onDismiss: () -> Void

    // 로켓 애니메이션
    @State private var rocketOffset: CGFloat = 0
    @State private var rocketScale: CGFloat = 1.0
    @State private var exhaustOpacity: Double = 0
    @State private var starTwinkle: Double = 0

    // 글로우 애니메이션
    @State private var glowRadius: CGFloat = 15
    @State private var showPhaseBanner: Bool = false
    @State private var phaseBannerText: String = ""

    var body: some View {
        ZStack {
            // 배경
            timerBackground

            VStack(spacing: 0) {
                // 상단 바
                topBar

                Spacer()

                // 로켓 + 원형 타이머
                timerRing

                Spacer()

                // 하단 컨트롤
                bottomControls
            }

            // 페이즈 전환 배너
            if showPhaseBanner {
                phaseBanner
            }
        }
        .onAppear {
            pomodoroVM.start()
            startAnimations()
        }
        .onChange(of: pomodoroVM.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    // MARK: - 배경

    private var timerBackground: some View {
        ZStack {
            // 집중: 딥 다크 / 휴식: 약간 따뜻한 색
            Group {
                if pomodoroVM.phase == .resting {
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.04, blue: 0.20),
                            Color(red: 0.12, green: 0.06, blue: 0.25),
                            Color(red: 0.04, green: 0.02, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.12),
                            Color(red: 0.05, green: 0.03, blue: 0.18),
                            Color(red: 0.01, green: 0.01, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .animation(.easeInOut(duration: 1.5), value: pomodoroVM.phase)
            .ignoresSafeArea()

            StarsOverlayView()
                .opacity(0.6 + starTwinkle * 0.4)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: starTwinkle)
                .ignoresSafeArea()
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack {
            Button(action: {
                pomodoroVM.pause()
                onDismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(12)
                    .background(Circle().fill(.white.opacity(0.1)))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(chapter.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(phaseLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(phaseColor.opacity(0.8))
            }

            Spacer()

            // 뽀모도로 카운터
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pomodoroVM.pomodoroCount ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.1)))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - 원형 타이머 + 로켓

    private var timerRing: some View {
        ZStack {
            // 원형 진행 링
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 14)
                .frame(width: 260, height: 260)

            Circle()
                .trim(from: 0, to: pomodoroVM.progress)
                .stroke(
                    AngularGradient(
                        colors: [phaseColor.opacity(0.4), phaseColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: pomodoroVM.progress)

            // 글로우 효과
            Circle()
                .fill(phaseColor.opacity(0.04))
                .frame(width: 240, height: 240)
                .blur(radius: glowRadius)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowRadius)

            // 타이머 내부
            VStack(spacing: 8) {
                // 로켓
                ZStack {
                    // 배기 불꽃
                    if pomodoroVM.phase == .focusing {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.8), .yellow.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 18, height: 28)
                            .offset(y: 34)
                            .opacity(exhaustOpacity)
                            .blur(radius: 3)
                    }

                    Text("🚀")
                        .font(.system(size: 52))
                        .rotationEffect(.degrees(pomodoroVM.phase == .focusing ? -90 : 90))
                        .offset(y: rocketOffset)
                        .scaleEffect(rocketScale)
                        .animation(.easeInOut(duration: 0.4), value: pomodoroVM.phase)
                }
                .frame(height: 80)

                // 시간
                Text(pomodoroVM.timeString)
                    .font(.system(size: 44, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 하단 컨트롤

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // 일시정지 / 재개
            Button(action: { pomodoroVM.togglePause() }) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: pomodoroVM.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 24) {
                // 휴식 스킵
                if pomodoroVM.phase == .resting {
                    Button(action: { pomodoroVM.skipRest() }) {
                        Label("휴식 건너뛰기", systemImage: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }

                // 챕터 완료
                Button(action: {
                    pomodoroVM.markCompleted()
                    pomodoroVM.saveFocusSession(to: chapter, context: modelContext)
                    onComplete()
                }) {
                    Label("챕터 완료", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4B70DD"), Color(hex: "#7B3FE4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                }
            }
        }
        .padding(.bottom, 52)
    }

    // MARK: - 페이즈 배너

    private var phaseBanner: some View {
        VStack {
            Spacer()
            Text(phaseBannerText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(phaseColor.opacity(0.3))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                )
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            Spacer()
        }
    }

    // MARK: - 헬퍼

    private var phaseLabel: String {
        switch pomodoroVM.phase {
        case .idle:      return "준비"
        case .focusing:  return "집중 중 🔥"
        case .resting:   return "휴식 중 😴"
        case .paused:    return "일시정지"
        case .completed: return "완료!"
        }
    }

    private var phaseColor: Color {
        switch pomodoroVM.phase {
        case .resting: return Color(hex: "#7B3FE4")
        default:       return Color(hex: "#4B70DD")
        }
    }

    // MARK: - 애니메이션

    private func startAnimations() {
        // 로켓 부유 애니메이션
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            rocketOffset = -10
        }
        // 배기 깜빡임
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            exhaustOpacity = 0.9
        }
        // 별 반짝임
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            starTwinkle = 1
        }
        // 글로우 맥박
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            glowRadius = 30
        }
    }

    private func handlePhaseChange(_ phase: PomodoroViewModel.Phase) {
        switch phase {
        case .resting:
            showPhaseBanner(text: "☕ 5분 휴식!")
            withAnimation(.easeInOut(duration: 0.6)) {
                rocketScale = 0.85
            }
        case .focusing:
            showPhaseBanner(text: "🚀 집중 시작!")
            withAnimation(.easeInOut(duration: 0.6)) {
                rocketScale = 1.0
            }
        default:
            break
        }
    }

    private func showPhaseBanner(text: String) {
        phaseBannerText = text
        withAnimation(.spring(response: 0.4)) {
            showPhaseBanner = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) {
                showPhaseBanner = false
            }
        }
    }
}
