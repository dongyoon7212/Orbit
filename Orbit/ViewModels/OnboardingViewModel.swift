// OnboardingViewModel.swift
// Orbit
//
// 온보딩 6단계 상태 관리 및 Claude 플랜 생성 조율

import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class OnboardingViewModel {

    // MARK: - 온보딩 단계

    enum Step: Int, CaseIterable {
        case certificationSelect = 0  // 1단계: 자격증 선택
        case examDate              = 1  // 2단계: 시험일 설정
        case studyDays             = 2  // 3단계: 공부 요일 선택
        case dailyHours            = 3  // 4단계: 하루 공부 시간
        case experienceLevel       = 4  // 5단계: 경험 수준
        case generatingPlan        = 5  // 6단계: AI 플랜 생성 중

        var title: String {
            switch self {
            case .certificationSelect: return "어떤 자격증을\n준비하시나요?"
            case .examDate: return "시험일이\n언제인가요?"
            case .studyDays: return "어떤 요일에\n공부하실 건가요?"
            case .dailyHours: return "하루에 얼마나\n공부하실 수 있나요?"
            case .experienceLevel: return "이 분야\n경험이 있으신가요?"
            case .generatingPlan: return "AI가 최적의\n탐사 플랜을 설계 중입니다"
            }
        }
    }

    // MARK: - 상태

    var currentStep: Step = .certificationSelect
    var isLoading = false
    var errorMessage: String?

    // 각 단계 선택값
    var availableCertifications: [CertificationDTO] = []
    var selectedCertificationId: String?
    var selectedCertificationName: String = ""

    var examDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    // 요일 선택 (0=일, 1=월, ..., 6=토)
    var selectedDays: Set<Int> = [1, 2, 3, 4, 5]  // 기본: 월~금

    // 하루 공부 시간 (분)
    var dailyStudyMinutes: Int = 60
    let minuteOptions: [Int] = [30, 60, 90, 120, 150, 180]

    var selectedExperience: ExperienceLevel = .beginner

    // MARK: - 플랜 생성 상태

    var planGenerationProgress: Double = 0.0
    var planGenerationMessage: String = "커리큘럼을 분석하고 있습니다..."

    // MARK: - 내비게이션

    var isOnboardingComplete = false

    // MARK: - 자격증 목록 로드

    func loadCertifications() async {
        do {
            availableCertifications = try await CertificationRepository.shared.loadAll()
            if let first = availableCertifications.first {
                selectedCertificationId = first.id
                selectedCertificationName = first.name
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 단계 이동

    func goNext() {
        let allSteps = Step.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = allSteps[currentIndex + 1]
        }
    }

    func goBack() {
        let allSteps = Step.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = allSteps[currentIndex - 1]
        }
    }

    var canGoNext: Bool {
        switch currentStep {
        case .certificationSelect:
            return selectedCertificationId != nil
        case .examDate:
            return examDate > Date()
        case .studyDays:
            return !selectedDays.isEmpty
        case .dailyHours:
            return dailyStudyMinutes > 0
        case .experienceLevel:
            return true
        case .generatingPlan:
            return false
        }
    }

    // MARK: - 플랜 생성 (최종 단계)

    func generatePlan(modelContext: ModelContext) async {
        guard let certId = selectedCertificationId else { return }

        currentStep = .generatingPlan
        isLoading = true
        errorMessage = nil

        do {
            // 1. 커리큘럼 로드
            planGenerationMessage = "커리큘럼을 불러오는 중..."
            planGenerationProgress = 0.1

            guard let certDTO = try await CertificationRepository.shared.find(id: certId) else {
                throw RepositoryError.notFound(certId)
            }

            planGenerationProgress = 0.2

            // 2. Claude API 플랜 생성
            planGenerationMessage = "AI가 맞춤 플랜을 설계 중..."
            planGenerationProgress = 0.3

            let planRequest = PlanRequest(
                certificationId: certId,
                certificationName: certDTO.name,
                subjects: certDTO.subjects,
                examDate: examDate,
                studyDaysPerWeek: Array(selectedDays).sorted(),
                dailyStudyMinutes: dailyStudyMinutes,
                experienceLevel: selectedExperience
            )

            let generatedPlan = try await ClaudeService.shared.generateStudyPlan(request: planRequest)
            planGenerationProgress = 0.7

            // 3. SwiftData 객체 생성
            planGenerationMessage = "탐사 미션을 구성하는 중..."

            let subjects = try await CertificationRepository.shared.buildSubjects(for: certId)

            // 생성된 플랜의 날짜를 챕터에 배정
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for assignment in generatedPlan.dailySchedule {
                guard let date = dateFormatter.date(from: assignment.date) else { continue }
                for subject in subjects {
                    for chapter in subject.chapters {
                        if assignment.chapterIds.contains(chapter.chapterId) {
                            chapter.plannedDate = date
                        }
                    }
                }
            }

            planGenerationProgress = 0.85

            // 4. UserMission 저장
            let mission = UserMission(
                certificationId: certId,
                certificationName: certDTO.name,
                examDate: examDate,
                studyDaysPerWeek: Array(selectedDays).sorted(),
                dailyStudyMinutes: dailyStudyMinutes,
                experienceLevel: selectedExperience
            )

            let tips = generatedPlan.tips?.map { $0.tip } ?? []
            let studyPlan = StudyPlan(
                claudeModel: "claude-sonnet-4-5",
                rawPlanJSON: (try? JSONEncoder().encode(generatedPlan)).flatMap { String(data: $0, encoding: .utf8) } ?? "",
                tips: tips
            )

            // DailyAssignment 생성
            for item in generatedPlan.dailySchedule {
                guard let date = dateFormatter.date(from: item.date) else { continue }
                let assignment = DailyAssignment(
                    date: date,
                    chapterIds: item.chapterIds,
                    totalMinutes: item.totalMinutes ?? 0
                )
                studyPlan.dailyAssignments.append(assignment)
                modelContext.insert(assignment)
            }

            for subject in subjects {
                subject.mission = mission
                mission.subjects.append(subject)
                modelContext.insert(subject)
                for chapter in subject.chapters {
                    modelContext.insert(chapter)
                }
            }

            mission.studyPlan = studyPlan
            modelContext.insert(studyPlan)
            modelContext.insert(mission)

            try modelContext.save()

            planGenerationProgress = 0.95

            // 5. EventKit 미리알림 등록 (권한 있는 경우에만)
            planGenerationMessage = "미리알림을 등록하는 중..."
            do {
                try await EventKitService.shared.requestAccess()
                try await EventKitService.shared.scheduleAllChapters(
                    subjects: subjects,
                    missionName: certDTO.name
                )
                try modelContext.save()
            } catch {
                // 미리알림 등록 실패는 치명적이지 않으므로 계속 진행
            }

            planGenerationProgress = 1.0
            planGenerationMessage = "탐사 준비 완료!"

            try? await Task.sleep(for: .seconds(1))
            isOnboardingComplete = true

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            // 오류 시 이전 단계로 복귀
            currentStep = .experienceLevel
        }

        isLoading = false
    }

    // MARK: - 요일 토글

    func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            // 최소 1개는 선택되어 있어야 함
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}
