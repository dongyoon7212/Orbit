// CertificationRepository.swift
// Orbit
//
// 앱 번들의 certifications.json을 로딩하고 SwiftData 객체로 변환

import Foundation
import SwiftData

// MARK: - JSON DTO

struct CertificationDB: Codable {
    let certifications: [CertificationDTO]
}

struct CertificationDTO: Codable, Identifiable {
    let id: String
    let name: String
    let organization: String
    let basedOn: String
    let planets: [PlanetDTO]

    /// 전체 챕터 수
    var totalChapterCount: Int { planets.flatMap(\.chapters).count }

    /// 전체 예상 공부 시간 (시간 단위)
    var totalEstimatedHours: Double { planets.flatMap(\.chapters).reduce(0) { $0 + $1.estimatedHours } }
}

struct PlanetDTO: Codable {
    let id: String
    let name: String
    let planet: String          // "mercury", "mars", "jupiter", "saturn" 등
    let chapters: [ChapterDTO]

    var totalEstimatedHours: Double { chapters.reduce(0) { $0 + $1.estimatedHours } }
    var totalWeight: Int { chapters.reduce(0) { $0 + $1.weight } }
}

struct ChapterDTO: Codable {
    let id: String
    let title: String
    let weight: Int             // 1(낮음) ~ 3(높음)
    let estimatedHours: Double

    /// weight → ImportanceLevel 변환
    var importanceLevel: ImportanceLevel {
        switch weight {
        case 3: return .high
        case 2: return .medium
        default: return .low
        }
    }

    /// 예상 공부 시간 (분 단위)
    var estimatedMinutes: Int { Int(estimatedHours * 60) }
}

// MARK: - Repository

actor CertificationRepository {
    static let shared = CertificationRepository()
    private var cachedDB: CertificationDB?

    private init() {}

    // MARK: - 전체 자격증 목록

    func loadAll() async throws -> [CertificationDTO] {
        try await loadDB().certifications
    }

    // MARK: - 특정 자격증 조회

    func find(id: String) async throws -> CertificationDTO? {
        try await loadDB().certifications.first { $0.id == id }
    }

    // MARK: - SwiftData 객체 빌드

    func buildSubjects(for certId: String) async throws -> [PlanetSubject] {
        guard let cert = try await find(id: certId) else {
            throw RepositoryError.notFound(certId)
        }

        return cert.planets.enumerated().map { index, planet in
            let planetType = PlanetType(rawValue: planet.planet) ?? .mercury
            let subject = PlanetSubject(
                subjectId: planet.id,
                name: planet.name,
                planetType: planetType,
                order: index,
                totalEstimatedHours: Int(planet.totalEstimatedHours)
            )
            subject.chapters = planet.chapters.enumerated().map { cIdx, ch in
                ExplorationChapter(
                    chapterId: ch.id,
                    title: ch.title,
                    estimatedMinutes: ch.estimatedMinutes,
                    importance: ch.importanceLevel,
                    order: cIdx,
                    weight: ch.weight
                )
            }
            return subject
        }
    }

    // MARK: - Private

    private func loadDB() async throws -> CertificationDB {
        if let cached = cachedDB { return cached }

        guard let url = Bundle.main.url(forResource: "certifications", withExtension: "json") else {
            throw RepositoryError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let db = try JSONDecoder().decode(CertificationDB.self, from: data)
        cachedDB = db
        return db
    }
}

// MARK: - Errors

enum RepositoryError: LocalizedError {
    case fileNotFound
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "커리큘럼 데이터 파일을 찾을 수 없습니다."
        case .notFound(let id):
            return "자격증 '\(id)'를 찾을 수 없습니다."
        }
    }
}
