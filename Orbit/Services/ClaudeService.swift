// ClaudeService.swift
// Orbit
//
// Cloudflare Worker 프록시를 통한 Claude API 호출
// 용도: 챕터 시작 시 1~2줄 코칭 멘트 생성 전용
// ⚠️ API 키는 Worker 환경변수에만 보관. 앱에는 Worker URL만 저장.

import Foundation

// MARK: - ClaudeService

actor ClaudeService {
    static let shared = ClaudeService()

    private let workerBaseURL = "https://orbit-worker.dongyoon7212.workers.dev"
    private let session = URLSession.shared

    private init() {}

    // MARK: - 챕터 코칭 멘트 생성

    /// 챕터 시작 시 1~2줄 코칭 멘트를 반환합니다.
    func generateCoachingMessage(
        chapterTitle: String,
        subjectName: String,
        certificationName: String,
        importanceLevel: ImportanceLevel
    ) async throws -> String {
        let prompt = """
        자격증 시험 코치입니다. 아래 챕터를 공부하기 시작하는 학생에게 1~2줄의 핵심 학습 팁을 한국어로 알려주세요.
        - 자격증: \(certificationName)
        - 과목: \(subjectName)
        - 챕터: \(chapterTitle)
        - 중요도: \(importanceLevel.displayName)

        규칙:
        - 반드시 1~2문장 이내
        - 실용적이고 구체적인 팁 (예: "계산 공식 암기 필수", "개념 위주로 가볍게")
        - 응원 문구 없이 팁만
        """

        return try await callClaude(prompt: prompt)
    }

    // MARK: - API 호출

    private func callClaude(prompt: String) async throws -> String {
        guard let url = URL(string: workerBaseURL + "/claude") else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // 코칭 멘트는 짧으므로 30초면 충분

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5",
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw ClaudeError.apiError(message)
        }

        guard let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.parseError("응답 형식 오류")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
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
