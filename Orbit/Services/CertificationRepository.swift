// CertificationRepository.swift
// Orbit
//
// 앱 번들의 certifications.json을 파싱해 제공하는 서비스

import Foundation

// MARK: - JSON 디코딩용 DTO

struct CertificationDB: Codable {
    let version: String
    let updatedAt: String
    let certifications: [CertificationDTO]
}

struct CertificationDTO: Codable, Identifiable {
    let id: String
    let name: String
    let nameEn: String
    let organization: String
    let curriculumYear: Int
    let examFormat: String
    let estimatedTotalHours: Int
    let subjects: [SubjectDTO]
}

struct SubjectDTO: Codable, Identifiable {
    let id: String
    let name: String
    let nameEn: String
    let planet: String
    let order: Int
    let estimatedHours: Int
    let chapters: [ChapterDTO]
}

struct ChapterDTO: Codable, Identifiable {
    let id: String
    let title: String
    let estimatedMinutes: Int
    let importance: String
    let order: Int
    let keywords: [String]
}

// MARK: - CertificationRepository

actor CertificationRepository {
    static let shared = CertificationRepository()

    private var cachedDB: CertificationDB?

    private init() {}

    func loadAll() async throws -> [CertificationDTO] {
        if let cached = cachedDB {
            return cached.certifications
        }

        guard let url = Bundle.main.url(forResource: "certifications", withExtension: "json") else {
            throw RepositoryError.fileNotFound("certifications.json")
        }

        let data = try Data(contentsOf: url)
        let db = try JSONDecoder().decode(CertificationDB.self, from: data)
        cachedDB = db
        return db.certifications
    }

    func find(id: String) async throws -> CertificationDTO? {
        let all = try await loadAll()
        return all.first { $0.id == id }
    }

    // UserMission 초기화에 필요한 SwiftData 객체들을 생성
    func buildSubjects(for certificationId: String) async throws -> [PlanetSubject] {
        guard let cert = try await find(id: certificationId) else {
            throw RepositoryError.notFound(certificationId)
        }

        return cert.subjects.map { subjectDTO in
            let planet = PlanetType(rawValue: subjectDTO.planet) ?? .mercury
            let subject = PlanetSubject(
                subjectId: subjectDTO.id,
                name: subjectDTO.name,
                planetType: planet,
                order: subjectDTO.order
            )

            subject.chapters = subjectDTO.chapters.map { chapterDTO in
                let importance = ImportanceLevel(rawValue: chapterDTO.importance) ?? .medium
                return ExplorationChapter(
                    chapterId: chapterDTO.id,
                    title: chapterDTO.title,
                    estimatedMinutes: chapterDTO.estimatedMinutes,
                    importance: importance,
                    order: chapterDTO.order
                )
            }

            return subject
        }
    }
}

// MARK: - Errors

enum RepositoryError: LocalizedError {
    case fileNotFound(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "리소스 파일을 찾을 수 없습니다: \(name)"
        case .notFound(let id):
            return "항목을 찾을 수 없습니다: \(id)"
        }
    }
}
