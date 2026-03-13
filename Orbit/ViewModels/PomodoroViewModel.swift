// PomodoroViewModel.swift
// Orbit
//
// 뽀모도로 타이머 상태 관리
// 25분 집중 / 5분 휴식, 일시정지/재개, 공부 시간 측정

import Foundation
import Observation
import SwiftData

@Observable
final class PomodoroViewModel {

    // MARK: - 타이머 상태

    enum Phase {
        case idle           // 시작 전
        case focusing       // 집중 중 (25분)
        case resting        // 휴식 중 (5분)
        case paused         // 일시정지
        case completed      // 챕터 완료
    }

    static let focusDuration: TimeInterval  = 25 * 60
    static let restDuration: TimeInterval   =  5 * 60

    private(set) var phase: Phase = .idle
    private(set) var timeRemaining: TimeInterval = focusDuration
    private(set) var pomodoroCount: Int = 0       // 완료된 뽀모도로 세트 수
    private(set) var totalStudiedSeconds: Int = 0 // 누적 순수 공부 시간 (집중 단계만)

    var progress: Double {
        let total = phase == .resting ? Self.restDuration : Self.focusDuration
        return 1.0 - timeRemaining / total
    }

    var timeString: String {
        let m = Int(timeRemaining) / 60
        let s = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isRunning: Bool { phase == .focusing || phase == .resting }

    // MARK: - 챕터 정보

    private(set) var chapter: ExplorationChapter?
    var coachingMessage: String = ""
    var isLoadingCoaching: Bool = false

    // MARK: - 내부 타이머

    private var task: Task<Void, Never>?
    private var pausedPhase: Phase = .idle

    // MARK: - 챕터 설정

    func setup(chapter: ExplorationChapter) {
        self.chapter = chapter
        phase = .idle
        timeRemaining = Self.focusDuration
        pomodoroCount = 0
        totalStudiedSeconds = 0
        coachingMessage = ""
    }

    // MARK: - 컨트롤

    func start() {
        guard phase == .idle || phase == .paused else { return }
        if phase == .idle {
            phase = .focusing
        } else {
            phase = pausedPhase
        }
        startTick()
    }

    func pause() {
        guard isRunning else { return }
        pausedPhase = phase
        phase = .paused
        task?.cancel()
        task = nil
    }

    func togglePause() {
        if isRunning { pause() } else { start() }
    }

    func skipRest() {
        guard phase == .resting else { return }
        task?.cancel()
        task = nil
        transitionToFocus()
    }

    func markCompleted() {
        task?.cancel()
        task = nil
        if phase == .focusing {
            // 남은 집중 시간을 공부 시간으로 산입
            let studiedNow = Int(Self.focusDuration - timeRemaining)
            totalStudiedSeconds += studiedNow
        }
        phase = .completed
    }

    // MARK: - 내부 틱

    private func startTick() {
        task?.cancel()
        task = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                await MainActor.run { self.tick() }
            }
        }
    }

    private func tick() {
        guard isRunning else { return }
        timeRemaining -= 1

        if phase == .focusing {
            totalStudiedSeconds += 1
        }

        if timeRemaining <= 0 {
            if phase == .focusing {
                pomodoroCount += 1
                transitionToRest()
            } else {
                transitionToFocus()
            }
        }
    }

    private func transitionToRest() {
        task?.cancel()
        task = nil
        phase = .resting
        timeRemaining = Self.restDuration
        startTick()
    }

    private func transitionToFocus() {
        phase = .focusing
        timeRemaining = Self.focusDuration
        startTick()
    }

    // MARK: - FocusSession 저장

    func saveFocusSession(to chapter: ExplorationChapter, context: ModelContext) {
        guard totalStudiedSeconds > 0 else { return }
        let session = FocusSession(plannedMinutes: Int(Self.focusDuration) / 60)
        session.endedAt = Date()
        session.actualMinutes = totalStudiedSeconds / 60
        session.wasCompleted = phase == .completed
        session.chapter = chapter
        chapter.sessions.append(session)
        context.insert(session)
        try? context.save()
    }
}
