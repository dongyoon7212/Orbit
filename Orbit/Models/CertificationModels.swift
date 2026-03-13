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
    var certificationId: String       // JSON DB의 자격증 ID
    var certificationName: String     // 예: "빅데이터분석기사"
    var examDate: Date                // 시험일 (D-Day 기준)
    var studyDaysPerWeek: [Int]       // 0=일, 1=월, ..., 6=토
    var dailyStudyMinutes: Int        // 하루 공부 가능 시간 (분)
    var experienceLevel: ExperienceLevel
    var createdAt: Date
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade)
    var subjects: [PlanetSubject]

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
    var subjectId: String
    var name: String
    var planetType: PlanetType
    var order: Int
    var totalEstimatedHours: Int      // 과목 전체 예상 공부 시간
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

    init(subjectId: String, name: String, planetType: PlanetType, order: Int, totalEstimatedHours: Int) {
        self.id = UUID()
        self.subjectId = subjectId
        self.name = name
        self.planetType = planetType
        self.order = order
        self.totalEstimatedHours = totalEstimatedHours
        self.isCompleted = false
        self.chapters = []
    }
}

// MARK: - ExplorationChapter (챕터 = 탐사 지점)

@Model
final class ExplorationChapter {
    var id: UUID
    var chapterId: String
    var title: String
    var estimatedMinutes: Int         // 예상 공부 시간 (분)
    var weight: Int                   // 중요도 가중치 1~3
    var importance: ImportanceLevel
    var order: Int
    var plannedDate: Date?            // 알고리즘이 배정한 공부 날짜
    var isCompleted: Bool
    var completedAt: Date?
    var reminderIdentifier: String?

    var subject: PlanetSubject?

    @Relationship(deleteRule: .cascade)
    var sessions: [FocusSession]

    init(
        chapterId: String,
        title: String,
        estimatedMinutes: Int,
        importance: ImportanceLevel,
        order: Int,
        weight: Int
    ) {
        self.id = UUID()
        self.chapterId = chapterId
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.weight = weight
        self.importance = importance
        self.order = order
        self.isCompleted = false
        self.sessions = []
    }
}

// MARK: - FocusSession (집중 타이머 세션)

@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var actualMinutes: Int
    var wasCompleted: Bool
    var whiteNoiseType: String?

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
    case beginner = "beginner"
    case experienced = "experienced"

    nonisolated var displayName: String {
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

    nonisolated var displayName: String {
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

    nonisolated var color: String {
        switch self {
        case .mercury: return "#B5B5B5"
        case .venus:   return "#E8C47A"
        case .mars:    return "#C1440E"
        case .jupiter: return "#C88B3A"
        case .saturn:  return "#E4D191"
        case .uranus:  return "#7DE8E8"
        case .neptune: return "#4B70DD"
        }
    }

    nonisolated var emoji: String {
        switch self {
        case .mercury: return "⚫️"
        case .venus:   return "🟡"
        case .mars:    return "🔴"
        case .jupiter: return "🟠"
        case .saturn:  return "🪐"
        case .uranus:  return "🔵"
        case .neptune: return "💙"
        }
    }
}

enum ImportanceLevel: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    nonisolated var displayName: String {
        switch self {
        case .high:   return "핵심"
        case .medium: return "중요"
        case .low:    return "보조"
        }
    }

    nonisolated var stars: Int {
        switch self {
        case .high:   return 3
        case .medium: return 2
        case .low:    return 1
        }
    }
}
