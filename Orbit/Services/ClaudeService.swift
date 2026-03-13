// ClaudeService.swift
// Orbit
//
// Cloudflare Worker 프록시를 통한 Claude API 호출
// ⚠️ API 키는 Worker 환경변수에만 보관. 앱에는 Worker URL만 저장.

import Foundation

// MARK: - 플랜 생성 요청 파라미터

struct PlanRequest {
    let certificationId: String
    let certificationName: String
    let subjects: [SubjectDTO]
    let examDate: Date
    let studyDaysPerWeek: [Int]
    let dailyStudyMinutes: Int
    let experienceLevel: ExperienceLevel
}

// MARK: - Claude 응답 구조체

struct GeneratedPlan: Codable {
    let dailySchedule: [DailyScheduleItem]
    let tips: [SubjectTip]?
    let totalStudyDays: Int?
    let reviewWeekStart: String?
}

struct DailyScheduleItem: Codable {
    let date: String
    let chapterIds: [String]
    let totalMinutes: Int?
    let memo: String?
}

struct SubjectTip: Codable {
    let subjectId: String
    let tip: String
    let chapterTips: [ChapterTip]?
}

struct ChapterTip: Codable {
    let chapterId: String
    let tip: String
}

// MARK: - ClaudeService

actor ClaudeService {
    static let shared = ClaudeService()

    // Worker URL — API 키가 아닌 공개 엔드포인트이므로 코드에 직접 보관
    // 실제 API 키는 Cloudflare Worker 환경변수에만 존재
    private let workerBaseURL = "https://orbit-worker.dongyoon7212.workers.dev"

    private let session = URLSession.shared
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private init() {}

    // MARK: - 공부 플랜 생성

    func generateStudyPlan(request: PlanRequest) async throws -> GeneratedPlan {
        guard !workerBaseURL.isEmpty else {
            throw ClaudeError.workerURLNotConfigured
        }

        let prompt = buildPlanPrompt(request: request)
        let responseText = try await callClaude(prompt: prompt)

        // Claude 응답에서 JSON 파싱
        return try parsePlanResponse(responseText)
    }

    // MARK: - Prompt 빌더

    private func buildPlanPrompt(request: PlanRequest) -> String {
        let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
        let studyDays = request.studyDaysPerWeek.map { weekdayNames[$0] }.joined(separator: ", ")
        let examDateStr = dateFormatter.string(from: request.examDate)
        let todayStr = dateFormatter.string(from: Date())

        let subjectsDescription = request.subjects.map { subject in
            let chapters = subject.chapters.map { ch in
                "  - ID:\(ch.id) [\(ch.importance.uppercased())] \(ch.title) (\(ch.estimatedMinutes)분)"
            }.joined(separator: "\n")
            return "### 과목ID:\(subject.id) \(subject.name)\n\(chapters)"
        }.joined(separator: "\n\n")

        return """
        당신은 자격증 공부 플래너입니다. 아래 정보를 바탕으로 최적의 일별 공부 스케줄을 JSON 형식으로 생성해주세요.

        ## 사용자 정보
        - 자격증: \(request.certificationName) (2024년 출제기준)
        - 오늘 날짜: \(todayStr)
        - 시험일: \(examDateStr)
        - 경험 수준: \(request.experienceLevel.displayName)
        - 공부 가능 요일: \(studyDays)
        - 하루 공부 가능 시간: \(request.dailyStudyMinutes)분

        ## 커리큘럼
        \(subjectsDescription)

        ## 요구사항
        1. 시험 1주 전(복습 주간)에는 새 챕터 배정 금지 — 복습과 모의고사만
        2. 중요도(HIGH > MEDIUM > LOW) 고려하여 배분
        3. 하루 배정 시간은 dailyStudyMinutes를 초과하지 않도록
        4. 경험자는 LOW 챕터 비중 줄이기
        5. 각 과목(subject)별로 순서대로 진행 (이전 과목 완료 후 다음 과목)

        ## 주의사항
        - chapterIds에는 반드시 위에 표기된 "ID:xxx" 형식의 실제 ID값만 사용 (챕터 제목 사용 금지)
        - subjectId, chapterId도 동일하게 실제 ID값 사용
        - 예시: "big_data_engineer_s1_c1" 형식

        ## 응답 형식 (```json 코드블록 없이 순수 JSON만 출력)
        {
          "dailySchedule": [
            {
              "date": "2026-03-14",
              "chapterIds": ["big_data_engineer_s1_c1"],
              "totalMinutes": 60,
              "memo": "오늘의 학습 메모"
            }
          ],
          "tips": [
            {
              "subjectId": "big_data_engineer_s1",
              "tip": "과목 전체 꿀팁",
              "chapterTips": [
                {
                  "chapterId": "big_data_engineer_s1_c1",
                  "tip": "챕터별 꿀팁"
                }
              ]
            }
          ],
          "totalStudyDays": 30,
          "reviewWeekStart": "2026-04-01"
        }
        """
    }

    // MARK: - API 호출

    private func callClaude(prompt: String) async throws -> String {
        guard let url = URL(string: workerBaseURL + "/claude") else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Worker가 Anthropic API 형식을 그대로 전달하므로 messages 형식으로 전송
        let body: [String: Any] = [
            "model": "claude-sonnet-4-5",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90  // Claude 응답은 최대 90초 대기

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.serverError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.parseError("응답을 파싱할 수 없습니다")
        }

        // Anthropic API 오류 응답: { "type": "error", "error": { "message": "..." } }
        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw ClaudeError.apiError(message)
        }

        // 정상 응답: { "content": [{"type": "text", "text": "..."}] }
        guard let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.parseError("응답 형식 오류: \(String(data: data, encoding: .utf8) ?? "")")
        }

        return text
    }

    // MARK: - 응답 파싱

    private func parsePlanResponse(_ text: String) throws -> GeneratedPlan {
        // 1) ```json ... ``` 블록 우선 추출
        let jsonText: String
        if let codeBlockStart = text.range(of: "```json"),
           let codeBlockEnd = text.range(of: "```", range: codeBlockStart.upperBound..<text.endIndex) {
            jsonText = String(text[codeBlockStart.upperBound..<codeBlockEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let codeBlockStart = text.range(of: "```"),
                  let codeBlockEnd = text.range(of: "```", range: codeBlockStart.upperBound..<text.endIndex) {
            jsonText = String(text[codeBlockStart.upperBound..<codeBlockEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let start = text.firstIndex(of: "{"),
                  let end = text.lastIndex(of: "}") {
            // 2) 코드블록 없으면 첫 { 부터 마지막 } 까지
            jsonText = String(text[start...end])
        } else {
            jsonText = text
        }

        guard let data = jsonText.data(using: .utf8) else {
            throw ClaudeError.parseError("UTF-8 인코딩 실패")
        }

        do {
            return try JSONDecoder().decode(GeneratedPlan.self, from: data)
        } catch {
            throw ClaudeError.parseError("플랜 JSON 파싱 실패: \(error.localizedDescription)\n원문: \(jsonText.prefix(300))")
        }
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case workerURLNotConfigured
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .workerURLNotConfigured:
            return "Cloudflare Worker URL이 설정되지 않았습니다."
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .serverError(let code, let body):
            return "서버 오류 (\(code)): \(body)"
        case .apiError(let message):
            return "AI 서비스 오류: \(message)"
        case .parseError(let msg):
            return "응답 파싱 실패: \(msg)"
        }
    }
}
