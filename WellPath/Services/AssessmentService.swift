//
//  AssessmentService.swift
//  WellPath
//
//  Service for fetching assessment data from database and saving results.
//  Supports all questionnaire-based views (Mental Health, Sleep, Stress, etc.)
//

import Foundation
import Supabase

@MainActor
class AssessmentService: ObservableObject {
    static let shared = AssessmentService()

    private let supabase = SupabaseManager.shared.client

    // Cache for assessment data
    private var assessmentCache: [String: AssessmentData] = [:]
    private var assessmentListCache: [String: [ViewAssessment]] = [:]

    private init() {}

    // MARK: - Fetch Assessments by Category

    /// Fetch all assessments for a category (e.g., CAT_MENTAL_HEALTH, CAT_SLEEP)
    func fetchAssessments(forCategory categoryId: String) async throws -> [ViewAssessment] {
        // Check cache
        if let cached = assessmentListCache[categoryId] {
            return cached
        }

        let response: [ViewAssessment] = try await supabase
            .from("view_assessments")
            .select()
            .eq("category_id", value: categoryId)
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value

        assessmentListCache[categoryId] = response
        return response
    }

    /// Fetch all assessments for a pillar
    func fetchAssessments(forPillar pillar: String) async throws -> [ViewAssessment] {
        let cacheKey = "pillar_\(pillar)"
        if let cached = assessmentListCache[cacheKey] {
            return cached
        }

        let response: [ViewAssessment] = try await supabase
            .from("view_assessments")
            .select()
            .eq("pillar", value: pillar)
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value

        assessmentListCache[cacheKey] = response
        return response
    }

    /// Fetch all active assessments
    func fetchAssessmentsAll() async throws -> [ViewAssessment] {
        let cacheKey = "all"
        if let cached = assessmentListCache[cacheKey] {
            return cached
        }

        let response: [ViewAssessment] = try await supabase
            .from("view_assessments")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value

        assessmentListCache[cacheKey] = response
        return response
    }

    // MARK: - Fetch Complete Assessment Data

    /// Fetch complete assessment data including questions, options, and tiers
    func fetchAssessmentData(assessmentId: String) async throws -> AssessmentData {
        // Check cache
        if let cached = assessmentCache[assessmentId] {
            return cached
        }

        // Fetch assessment
        let assessments: [ViewAssessment] = try await supabase
            .from("view_assessments")
            .select()
            .eq("assessment_id", value: assessmentId)
            .limit(1)
            .execute()
            .value

        guard let assessment = assessments.first else {
            throw AssessmentError.notFound(assessmentId)
        }

        // Fetch questions
        let questions: [ViewAssessmentQuestion] = try await supabase
            .from("view_assessment_questions")
            .select()
            .eq("assessment_id", value: assessmentId)
            .order("question_order")
            .execute()
            .value

        // Fetch all response options for these questions
        let questionIds = questions.map { $0.questionId }
        let allOptions: [ViewAssessmentResponseOption] = try await supabase
            .from("view_assessment_response_options")
            .select()
            .in("question_id", values: questionIds)
            .order("display_order")
            .execute()
            .value

        // Group options by question ID
        var optionsByQuestion: [String: [ViewAssessmentResponseOption]] = [:]
        for option in allOptions {
            optionsByQuestion[option.questionId, default: []].append(option)
        }

        // Fetch tiers
        let tiers: [ViewAssessmentTier] = try await supabase
            .from("view_assessment_tiers")
            .select()
            .eq("assessment_id", value: assessmentId)
            .order("tier_order")
            .execute()
            .value

        let data = AssessmentData(
            assessment: assessment,
            questions: questions,
            responseOptions: optionsByQuestion,
            tiers: tiers
        )

        assessmentCache[assessmentId] = data
        return data
    }

    // MARK: - Fetch Latest Score

    /// Fetch the latest score for an assessment
    func fetchLatestScore(assessmentId: String) async throws -> (score: Int, date: Date)? {
        guard let userId = try? await supabase.auth.session.user.id else {
            return nil
        }

        struct ResultResponse: Codable {
            let totalScore: Int
            let completedAt: Date

            enum CodingKeys: String, CodingKey {
                case totalScore = "total_score"
                case completedAt = "completed_at"
            }
        }

        let response: [ResultResponse] = try await supabase
            .from("patient_assessment_results")
            .select("total_score, completed_at")
            .eq("patient_id", value: userId.uuidString)
            .eq("assessment_id", value: assessmentId)
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let result = response.first else {
            return nil
        }

        return (result.totalScore, result.completedAt)
    }

    /// Fetch score history for an assessment (including responses for filtering)
    func fetchScoreHistory(assessmentId: String, limit: Int = 30) async throws -> [AssessmentResult] {
        guard let userId = try? await supabase.auth.session.user.id else {
            return []
        }

        let assessmentData = try await fetchAssessmentData(assessmentId: assessmentId)

        struct ResultResponse: Codable {
            let id: UUID
            let totalScore: Int
            let tierKey: String?
            let completedAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case totalScore = "total_score"
                case tierKey = "tier_key"
                case completedAt = "completed_at"
            }
        }

        let response: [ResultResponse] = try await supabase
            .from("patient_assessment_results")
            .select("id, total_score, tier_key, completed_at")
            .eq("patient_id", value: userId.uuidString)
            .eq("assessment_id", value: assessmentId)
            .order("completed_at", ascending: true)
            .limit(limit)
            .execute()
            .value

        // Fetch all responses for these results in one query
        let resultIds = response.map { $0.id.uuidString }
        var responsesByResult: [UUID: [String: Int]] = [:]

        if !resultIds.isEmpty {
            struct ResponseRow: Codable {
                let resultId: String
                let questionId: String
                let responseValue: Int

                enum CodingKeys: String, CodingKey {
                    case resultId = "result_id"
                    case questionId = "question_id"
                    case responseValue = "response_value"
                }
            }

            let allResponses: [ResponseRow] = try await supabase
                .from("patient_assessment_responses")
                .select("result_id, question_id, response_value")
                .in("result_id", values: resultIds)
                .execute()
                .value

            for resp in allResponses {
                guard let uuid = UUID(uuidString: resp.resultId) else { continue }
                responsesByResult[uuid, default: [:]][resp.questionId] = resp.responseValue
            }
        }

        return response.map { result in
            let tier = assessmentData.tier(for: result.totalScore)
            return AssessmentResult(
                id: result.id,
                date: result.completedAt,
                score: result.totalScore,
                tierName: tier?.tierName,
                tierColor: tier?.color,
                responses: responsesByResult[result.id]
            )
        }
    }

    // MARK: - Delete Assessment Result

    /// Delete an assessment result by ID (responses cascade delete)
    func deleteAssessmentResult(resultId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw AssessmentError.notAuthenticated
        }

        try await supabase
            .from("patient_assessment_results")
            .delete()
            .eq("id", value: resultId.uuidString)
            .eq("patient_id", value: userId.uuidString)  // Security: ensure user owns the record
            .execute()
    }

    // MARK: - Save Assessment Result

    /// Save an assessment result with individual responses
    func saveAssessmentResult(
        assessmentId: String,
        score: Int,
        responses: [String: Int]
    ) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw AssessmentError.notAuthenticated
        }

        let now = Date()
        let timezone = TimeZone.current.identifier

        // Determine tier
        let assessmentData = try await fetchAssessmentData(assessmentId: assessmentId)
        let tier = assessmentData.tier(for: score)

        // 1. Insert result
        struct ResultInsert: Codable {
            let patientId: String
            let assessmentId: String
            let totalScore: Int
            let tierKey: String?
            let completedAt: Date
            let timezone: String?

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case assessmentId = "assessment_id"
                case totalScore = "total_score"
                case tierKey = "tier_key"
                case completedAt = "completed_at"
                case timezone
            }
        }

        struct ResultResponse: Codable {
            let id: UUID
        }

        let resultInsert = ResultInsert(
            patientId: userId.uuidString,
            assessmentId: assessmentId,
            totalScore: score,
            tierKey: tier?.tierKey,
            completedAt: now,
            timezone: timezone
        )

        let resultResponse: [ResultResponse] = try await supabase
            .from("patient_assessment_results")
            .insert(resultInsert)
            .select("id")
            .execute()
            .value

        guard let resultId = resultResponse.first?.id else {
            throw AssessmentError.saveFailed(NSError(domain: "AssessmentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get result ID"]))
        }

        // 2. Insert individual responses
        struct ResponseInsert: Codable {
            let resultId: String
            let questionId: String
            let responseValue: Int

            enum CodingKeys: String, CodingKey {
                case resultId = "result_id"
                case questionId = "question_id"
                case responseValue = "response_value"
            }
        }

        let responseInserts = responses.map { questionId, value in
            ResponseInsert(
                resultId: resultId.uuidString,
                questionId: questionId,
                responseValue: value
            )
        }

        if !responseInserts.isEmpty {
            try await supabase
                .from("patient_assessment_responses")
                .insert(responseInserts)
                .execute()
        }
    }

    // MARK: - Fetch Responses for a Result

    /// Fetch individual question responses for a specific assessment result
    func fetchResponses(resultId: UUID) async throws -> [String: Int] {
        struct ResponseRow: Codable {
            let questionId: String
            let responseValue: Int

            enum CodingKeys: String, CodingKey {
                case questionId = "question_id"
                case responseValue = "response_value"
            }
        }

        let responses: [ResponseRow] = try await supabase
            .from("patient_assessment_responses")
            .select("question_id, response_value")
            .eq("result_id", value: resultId.uuidString)
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: responses.map { ($0.questionId, $0.responseValue) })
    }

    // MARK: - Cache Management

    func clearCache() {
        assessmentCache.removeAll()
        assessmentListCache.removeAll()
    }

    func clearCache(for assessmentId: String) {
        assessmentCache.removeValue(forKey: assessmentId)
    }
}

// MARK: - Errors

enum AssessmentError: LocalizedError {
    case notFound(String)
    case notAuthenticated
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Assessment not found: \(id)"
        case .notAuthenticated:
            return "User not authenticated"
        case .saveFailed(let error):
            return "Failed to save assessment: \(error.localizedDescription)"
        }
    }
}
