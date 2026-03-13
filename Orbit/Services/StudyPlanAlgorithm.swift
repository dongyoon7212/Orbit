// StudyPlanAlgorithm.swift
// Orbit
//
// 알고리즘 기반 챕터 날짜 분배
// Claude API 없이 오프라인 즉시 동작

import Foundation

struct StudyPlanAlgorithm {

    // MARK: - Public Interface

    /// 챕터 목록에 plannedDate를 배정하여 반환
    /// - Parameters:
    ///   - subjects: SwiftData PlanetSubject 배열 (chapters 포함)
    ///   - examDate: 시험일
    ///   - studyDaysPerWeek: 공부 요일 (0=일 ~ 6=토)
    ///   - dailyStudyMinutes: 하루 공부 가능 시간 (분)
    ///   - experienceLevel: 경험 수준 (경험자는 low weight 챕터 축소)
    static func assignDates(
        subjects: [PlanetSubject],
        examDate: Date,
        studyDaysPerWeek: [Int],
        dailyStudyMinutes: Int,
        experienceLevel: ExperienceLevel
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let exam = calendar.startOfDay(for: examDate)

        // 시험 1주 전부터는 복습 주간 → 새 챕터 배정 금지
        let reviewStart = calendar.date(byAdding: .day, value: -7, to: exam) ?? exam

        // 공부 가능한 날짜 목록 생성 (오늘 ~ 복습주간 직전)
        var studyDates: [Date] = []
        var cursor = today
        while cursor < reviewStart {
            let weekday = calendar.component(.weekday, from: cursor) - 1  // 0=일
            if studyDaysPerWeek.contains(weekday) {
                studyDates.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        // 경험자: weight=1 챕터의 estimatedMinutes를 50% 감소 (복사본에서 처리)
        let allChapters: [ExplorationChapter] = subjects
            .sorted { $0.order < $1.order }
            .flatMap { $0.chapters.sorted { $0.order < $1.order } }

        // 각 챕터별 실제 배정 시간 계산
        let effectiveMinutes: [String: Int] = Dictionary(
            uniqueKeysWithValues: allChapters.map { chapter in
                var minutes = chapter.estimatedMinutes
                if experienceLevel == .experienced && chapter.weight == 1 {
                    minutes = max(15, minutes / 2)
                }
                return (chapter.chapterId, minutes)
            }
        )

        // 날짜 순서대로 챕터를 채워나가는 그리디 분배
        var dateIndex = 0
        var minutesUsedToday = 0

        for chapter in allChapters {
            guard dateIndex < studyDates.count else {
                // 남은 날짜 없음 → 마지막 공부일에 몰아서 배정
                chapter.plannedDate = studyDates.last ?? today
                continue
            }

            let needed = effectiveMinutes[chapter.chapterId] ?? chapter.estimatedMinutes

            // 오늘 남은 시간으로 챕터 시작 가능한지 확인 (최소 15분)
            if minutesUsedToday + 15 > dailyStudyMinutes {
                dateIndex += 1
                minutesUsedToday = 0
                if dateIndex >= studyDates.count {
                    chapter.plannedDate = studyDates.last ?? today
                    continue
                }
            }

            chapter.plannedDate = studyDates[dateIndex]
            minutesUsedToday += needed

            // 챕터 완료 후 오늘 시간 초과 시 다음 날로
            if minutesUsedToday >= dailyStudyMinutes {
                dateIndex += 1
                minutesUsedToday = 0
            }
        }
    }

    // MARK: - 플랜 요약 계산

    struct PlanSummary {
        let totalStudyDays: Int           // 공부 날짜 수
        let totalChapters: Int            // 전체 챕터 수
        let totalEstimatedHours: Double   // 전체 예상 공부 시간
        let reviewWeekStart: Date?        // 복습 주간 시작일
        let subjectSummaries: [SubjectSummary]
    }

    struct SubjectSummary {
        let subjectName: String
        let chapterCount: Int
        let estimatedHours: Double
        let firstStudyDate: Date?
        let lastStudyDate: Date?
    }

    static func buildSummary(subjects: [PlanetSubject], examDate: Date) -> PlanSummary {
        let calendar = Calendar.current
        let reviewWeekStart = calendar.date(byAdding: .day, value: -7, to: examDate)

        let allChapters = subjects.flatMap { $0.chapters }
        let studyDates = Set(allChapters.compactMap { $0.plannedDate?.startOfDay })

        let subjectSummaries: [SubjectSummary] = subjects.sorted { $0.order < $1.order }.map { subject in
            let dates = subject.chapters.compactMap { $0.plannedDate }
            return SubjectSummary(
                subjectName: subject.name,
                chapterCount: subject.chapters.count,
                estimatedHours: Double(subject.totalEstimatedHours),
                firstStudyDate: dates.min(),
                lastStudyDate: dates.max()
            )
        }

        return PlanSummary(
            totalStudyDays: studyDates.count,
            totalChapters: allChapters.count,
            totalEstimatedHours: Double(subjects.reduce(0) { $0 + $1.totalEstimatedHours }),
            reviewWeekStart: reviewWeekStart,
            subjectSummaries: subjectSummaries
        )
    }
}

// MARK: - Date Helper

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
