// EventKitService.swift
// Orbit
//
// EventKit을 통한 미리알림 앱 연동

import Foundation
import EventKit

actor EventKitService {
    static let shared = EventKitService()

    private let store = EKEventStore()
    private var isAuthorized = false

    private init() {}

    // MARK: - 권한 요청

    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            isAuthorized = try await store.requestFullAccessToReminders()
        } else {
            isAuthorized = try await store.requestAccess(to: .reminder)
        }

        guard isAuthorized else {
            throw EventKitError.accessDenied
        }
    }

    // MARK: - 챕터 미리알림 등록

    func scheduleReminder(for chapter: ExplorationChapter, on date: Date, missionName: String) async throws -> String {
        guard isAuthorized else {
            throw EventKitError.notAuthorized
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = "[\(missionName)] \(chapter.title)"
        reminder.notes = "Orbit 공부 플랜 — 예상 \(chapter.estimatedMinutes)분"
        reminder.calendar = store.defaultCalendarForNewReminders()

        // 해당 날짜 오전 9시로 알림 설정
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0

        let alarm = EKAlarm(absoluteDate: Calendar.current.date(from: components) ?? date)
        reminder.addAlarm(alarm)

        // 마감일 설정
        reminder.dueDateComponents = components

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    // MARK: - 챕터 완료 처리 (미리알림 완료 표시)

    func completeReminder(identifier: String) async throws {
        guard isAuthorized else { return }

        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return  // 이미 삭제됐거나 없으면 무시
        }

        reminder.isCompleted = true
        try store.save(reminder, commit: true)
    }

    // MARK: - 미리알림 삭제

    func deleteReminder(identifier: String) async throws {
        guard isAuthorized else { return }

        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return
        }

        try store.remove(reminder, commit: true)
    }

    // MARK: - 배치 등록 (플랜 생성 후 전체 챕터 등록)

    func scheduleAllChapters(subjects: [PlanetSubject], missionName: String) async throws {
        for subject in subjects {
            for chapter in subject.chapters {
                guard let plannedDate = chapter.plannedDate else { continue }
                let identifier = try await scheduleReminder(
                    for: chapter,
                    on: plannedDate,
                    missionName: missionName
                )
                chapter.reminderIdentifier = identifier
            }
        }
    }
}

// MARK: - Errors

enum EventKitError: LocalizedError {
    case accessDenied
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "미리알림 접근 권한이 거부되었습니다. 설정 앱에서 권한을 허용해 주세요."
        case .notAuthorized:
            return "미리알림 권한이 없습니다. requestAccess()를 먼저 호출하세요."
        }
    }
}
