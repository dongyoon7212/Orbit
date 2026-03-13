// OnboardingViewModel.swift
// Orbit
//
// 온보딩 6단계 상태 관리 및 알고리즘 기반 플랜 생성

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
        case planConfirm           = 5  // 6단계: 플랜 확인 (알고리즘 즉시 계산)

        var title: String {
            switch self {
            case .certificationSelect: return "어떤 자격증을\n준비하시나요?"
            case .examDate:            return "시험일이\n언제인가요?"
            case .studyDays:           return "어떤 요일에\n공부하실 건가요?"
            case .dailyHours:          return "하루에 얼마나\n공부하실 수 있나요?"
            case .experienceLevel:     return "이 분야\n경험이 있으신가요?"
            case .planConfirm:         return "탐사 플랜이\n준비되었습니다"
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

    var selectedDays: Set<Int> = [1, 2, 3, 4, 5]  // 기본: 월~금

    var dailyStudyMinutes: Int = 60
    let minuteOptions: [Int] = [30, 60, 90, 120, 150, 180]

    var selectedExperience: ExperienceLevel = .beginner

    // 플랜 확인 단계에서 표시할 요약
    var planSummary: StudyPlanAlgorithm.PlanSummary?
    var previewSubjects: [PlanetSubject] = []  // 알고리즘 계산 결과 (미리보기)

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
        case .planConfirm:
            return false  // "탐사 시작" 버튼으로 처리
        }
    }

    // MARK: - 경험 수준 선택 후 플랜 미리보기 생성

    /// 경험 수준 화면 → 플랜 확인 화면 진입 시 알고리즘 즉시 실행
    func computePlanPreview() async {
        guard let certId = selectedCertificationId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let subjects = try await CertificationRepository.shared.buildSubjects(for: certId)

            StudyPlanAlgorithm.assignDates(
                subjects: subjects,
                examDate: examDate,
                studyDaysPerWeek: Array(selectedDays).sorted(),
                dailyStudyMinutes: dailyStudyMinutes,
                experienceLevel: selectedExperience
            )

            let summary = StudyPlanAlgorithm.buildSummary(subjects: subjects, examDate: examDate)
            previewSubjects = subjects
            planSummary = summary
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 플랜 확정 및 저장 (탐사 시작)

    func confirmAndSave(modelContext: ModelContext) async {
        guard let certId = selectedCertificationId,
              !previewSubjects.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // UserMission 생성
            let mission = UserMission(
                certificationId: certId,
                certificationName: selectedCertificationName,
                examDate: examDate,
                studyDaysPerWeek: Array(selectedDays).sorted(),
                dailyStudyMinutes: dailyStudyMinutes,
                experienceLevel: selectedExperience
            )

            // 과목 및 챕터 저장
            for subject in previewSubjects {
                subject.mission = mission
                mission.subjects.append(subject)
                modelContext.insert(subject)
                for chapter in subject.chapters {
                    modelContext.insert(chapter)
                }
            }

            modelContext.insert(mission)
            try modelContext.save()

            // EventKit 미리알림 등록 (권한 있는 경우에만)
            do {
                try await EventKitService.shared.requestAccess()
                if let certDTO = try await CertificationRepository.shared.find(id: certId) {
                    try await EventKitService.shared.scheduleAllChapters(
                        subjects: previewSubjects,
                        missionName: certDTO.name
                    )
                    try modelContext.save()
                }
            } catch {
                // 미리알림 실패는 비치명적
            }

            isOnboardingComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 요일 토글

    func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}
