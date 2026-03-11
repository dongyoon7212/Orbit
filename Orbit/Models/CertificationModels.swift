// CertificationModels.swift
// Orbit
//
// SwiftData 모델: 자격증, 과목(행성), 챕터(탐사 지점)

import Foundation
import SwiftData

// MARK: - UserMission (자격증 탐사 미션)
@Model
final class UserMission {
    var id: UUID
    var certificationId: String       // JSON DB의 자격증 ID와 매핑
    var certificationName: String     // 예: "빅데이터분석기사"
    var examDate: Date                // 시험일 (D-Day 기준)
    var studyDaysPerWeek: [Int]       // 0=일, 1=월, ..., 6=토
    var dailyStudyMinutes: Int        // 하루 공부 가능 시간 (분)
    var experienceLevel: ExperienceLevel
    var createdAt: Date
    var isCompleted: Bool             // 자격증 취득 완료 여부

    @Relationship(deleteRule: .cascade)
    var subjects: [PlanetSubject]

    @Relationship(deleteRule: .cascade)
    var studyPlan: StudyPlan?

    init(
        certificationId: String,
        certificationName: String,
        examDate: Date,
        studyDaysPerWeek: [Int],
        dailyStudyMinutes: Int,
        experienceLevel: ExperienceLevel
    ) {
        self.id = UUID()
        self.certificationId = certificationId
        self.certificationName = certificationName
        self.examDate = examDate
        self.studyDaysPerWeek = studyDaysPerWeek
        self.dailyStudyMinutes = dailyStudyMinutes
        self.experienceLevel = experienceLevel
        self.createdAt = Date()
        self.isCompleted = false
        self.subjects = []
    }
}

// MARK: - PlanetSubject (과목 = 행성)
@Model
final class PlanetSubject {
    var id: UUID
    var subjectId: String             // JSON DB 과목 ID
    var name: String                  // 예: "빅데이터 분석 기획"
    var planetType: PlanetType        // 행성 종류
    var order: Int                    // 탐사 순서
    var isCompleted: Bool
    var completedAt: Date?

    @Relationship(deleteRule: .cascade)
    var chapters: [ExplorationChapter]

    var mission: UserMission?

    var completionRate: Double {
        guard !chapters.isEmpty else { return 0 }
        let completed = chapters.filter { $0.isCompleted }.count
        return Double(completed) / Double(chapters.count)
    }

    init(subjectId: String, name: String, planetType: PlanetType, order: Int) {
        self.id = UUID()
        self.subjectId = subjectId
        self.name = name
        self.planetType = planetType
        self.order = order
        self.isCompleted = false
        self.chapters = []
    }
}

// MARK: - ExplorationChapter (챕터 = 탐사 지점)
@Model
final class ExplorationChapter {
    var id: UUID
    var chapterId: String             // JSON DB 챕터 ID
    var title: String                 // 챕터 제목
    var estimatedMinutes: Int         // 예상 공부 시간 (분)
    var importance: ImportanceLevel   // 중요도 (high/medium/low)
    var order: Int                    // 챕터 순서
    var plannedDate: Date?            // AI가 배정한 공부 날짜
    var isCompleted: Bool
    var completedAt: Date?
    var reminderIdentifier: String?   // EventKit 미리알림 ID

    var subject: PlanetSubject?

    @Relationship(deleteRule: .cascade)
    var sessions: [FocusSession]

    init(
        chapterId: String,
        title: String,
        estimatedMinutes: Int,
        importance: ImportanceLevel,
        order: Int
    ) {
        self.id = UUID()
        self.chapterId = chapterId
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.importance = importance
        self.order = order
        self.isCompleted = false
        self.sessions = []
    }
}

// MARK: - StudyPlan (AI 생성 공부 플랜)
@Model
final class StudyPlan {
    var id: UUID
    var generatedAt: Date
    var claudeModel: String           // 생성에 사용된 Claude 모델 버전
    var rawPlanJSON: String           // Claude 응답 원본 JSON 저장
    var tips: [String]                // 과목/챕터별 꿀팁

    var mission: UserMission?

    @Relationship(deleteRule: .cascade)
    var dailyAssignments: [DailyAssignment]

    init(claudeModel: String, rawPlanJSON: String, tips: [String]) {
        self.id = UUID()
        self.generatedAt = Date()
        self.claudeModel = claudeModel
        self.rawPlanJSON = rawPlanJSON
        self.tips = tips
        self.dailyAssignments = []
    }
}

// MARK: - DailyAssignment (일별 챕터 배정)
@Model
final class DailyAssignment {
    var id: UUID
    var date: Date
    var chapterIds: [String]          // 해당 날짜에 배정된 챕터 ID 목록
    var totalMinutes: Int
    var isCompleted: Bool

    var plan: StudyPlan?

    init(date: Date, chapterIds: [String], totalMinutes: Int) {
        self.id = UUID()
        self.date = date
        self.chapterIds = chapterIds
        self.totalMinutes = totalMinutes
        self.isCompleted = false
    }
}

// MARK: - FocusSession (집중 타이머 세션)
@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var actualMinutes: Int            // 실제 집중한 시간
    var wasCompleted: Bool            // 정상 완료 여부 (중간 종료 = false)
    var whiteNoiseType: String?       // 사용한 백색소음 종류

    var chapter: ExplorationChapter?

    init(plannedMinutes: Int) {
        self.id = UUID()
        self.startedAt = Date()
        self.plannedMinutes = plannedMinutes
        self.actualMinutes = 0
        self.wasCompleted = false
    }
}

// MARK: - MissedDayLog (미달성 기록)
@Model
final class MissedDayLog {
    var id: UUID
    var missedDate: Date
    var missedChapterIds: [String]
    var missedMinutes: Int
    var recoveryStrategy: RecoveryStrategy?
    var isResolved: Bool
    var resolvedAt: Date?

    init(missedDate: Date, missedChapterIds: [String], missedMinutes: Int) {
        self.id = UUID()
        self.missedDate = missedDate
        self.missedChapterIds = missedChapterIds
        self.missedMinutes = missedMinutes
        self.isResolved = false
    }
}

// MARK: - Enums

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "beginner"       // 입문
    case experienced = "experienced" // 경험자

    var displayName: String {
        switch self {
        case .beginner: return "입문"
        case .experienced: return "경험자"
        }
    }
}

enum PlanetType: String, Codable, CaseIterable {
    case mercury = "mercury"
    case venus = "venus"
    case mars = "mars"
    case jupiter = "jupiter"
    case saturn = "saturn"
    case uranus = "uranus"
    case neptune = "neptune"

    var displayName: String {
        switch self {
        case .mercury: return "수성"
        case .venus: return "금성"
        case .mars: return "화성"
        case .jupiter: return "목성"
        case .saturn: return "토성"
        case .uranus: return "천왕성"
        case .neptune: return "해왕성"
        }
    }

    var color: String {
        switch self {
        case .mercury: return "#B5B5B5"
        case .venus: return "#E8C47A"
        case .mars: return "#C1440E"
        case .jupiter: return "#C88B3A"
        case .saturn: return "#E4D191"
        case .uranus: return "#7DE8E8"
        case .neptune: return "#4B70DD"
        }
    }
}

enum ImportanceLevel: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return "핵심"
        case .medium: return "중요"
        case .low: return "보조"
        }
    }

    var weight: Double {
        switch self {
        case .high: return 1.5
        case .medium: return 1.0
        case .low: return 0.7
        }
    }
}

enum RecoveryStrategy: String, Codable {
    case autoDistribute = "auto_distribute"   // 자동 분배
    case skipLowImportance = "skip_low"       // 중요도 낮은 챕터 스킵
    case claudeReplan = "claude_replan"       // Claude 재플랜
    case continueNormal = "continue_normal"   // 그냥 진행
}
