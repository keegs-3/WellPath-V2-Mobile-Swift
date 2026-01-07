//
//  JourneyStateService.swift
//  WellPath
//
//  Centralized service for tracking patient journey state across the app.
//  Used to determine whether to show demo/tour content vs real data.
//

import Foundation
import Combine

// MARK: - Journey State (copied from GoalsViewModel for app-wide access)

enum JourneyState: Equatable {
    case loading
    case baselineCollection(completed: Int, total: Int)
    case awaitingLabs
    case awaitingBiometrics
    case awaitingClinicianReview
    case activeGoals
    case cycleComplete

    /// Human-readable status title
    var statusTitle: String {
        switch self {
        case .loading:
            return "Loading..."
        case .baselineCollection(let completed, let total):
            return "Setting Up (\(completed)/\(total))"
        case .awaitingLabs:
            return "Awaiting Lab Results"
        case .awaitingBiometrics:
            return "Awaiting Biometrics"
        case .awaitingClinicianReview:
            return "Awaiting Clinician Review"
        case .activeGoals:
            return "Active Cycle"
        case .cycleComplete:
            return "Cycle Complete"
        }
    }

    /// Detailed status message
    var statusMessage: String {
        switch self {
        case .loading:
            return "Loading your data..."
        case .baselineCollection(let completed, let total):
            return "\(completed) of \(total) baselines complete"
        case .awaitingLabs:
            return "Your clinician will enter your lab results"
        case .awaitingBiometrics:
            return "Your clinician will enter your biometrics"
        case .awaitingClinicianReview:
            return "Your clinician is preparing your personalized plan"
        case .activeGoals:
            return "Track your goals and build healthy habits"
        case .cycleComplete:
            return "Review your progress and prepare for the next cycle"
        }
    }

    /// Icon for status card
    var statusIcon: String {
        switch self {
        case .loading:
            return "arrow.clockwise"
        case .baselineCollection:
            return "checklist"
        case .awaitingLabs:
            return "testtube.2"
        case .awaitingBiometrics:
            return "waveform.path.ecg"
        case .awaitingClinicianReview:
            return "person.badge.clock"
        case .activeGoals:
            return "target"
        case .cycleComplete:
            return "flag.checkered"
        }
    }

    /// Progress percentage for status card (0-100)
    var progressPercentage: Double {
        switch self {
        case .loading:
            return 0
        case .baselineCollection(let completed, let total):
            return total > 0 ? Double(completed) / Double(total) * 100 : 0
        case .awaitingLabs:
            return 40 // Baselines done
        case .awaitingBiometrics:
            return 55 // Labs done
        case .awaitingClinicianReview:
            return 70 // All data in
        case .activeGoals:
            return 100
        case .cycleComplete:
            return 100
        }
    }
}

// MARK: - Journey State Service

@MainActor
class JourneyStateService: ObservableObject {
    static let shared = JourneyStateService()

    // MARK: - Published Properties

    @Published private(set) var state: JourneyState = .loading
    @Published private(set) var onboardingStatus: PatientOnboardingStatus?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // Cycle information
    @Published private(set) var currentCycleNumber: Int = 1
    @Published private(set) var cycleStartDate: Date?
    @Published private(set) var cycleEndDate: Date?
    @Published private(set) var cycleWeek: Int = 1

    // MARK: - Computed Properties

    /// Whether to show demo content instead of real data
    var shouldShowDemo: Bool {
        switch state {
        case .loading, .baselineCollection, .awaitingLabs, .awaitingBiometrics, .awaitingClinicianReview:
            return true
        case .activeGoals, .cycleComplete:
            return false
        }
    }

    /// Whether onboarding is in progress (baselines not complete)
    var isOnboarding: Bool {
        switch state {
        case .baselineCollection:
            return true
        default:
            return false
        }
    }

    /// Whether waiting for clinician actions
    var isAwaitingClinician: Bool {
        switch state {
        case .awaitingLabs, .awaitingBiometrics, .awaitingClinicianReview:
            return true
        default:
            return false
        }
    }

    /// Whether the patient has an active goal cycle
    var hasActiveCycle: Bool {
        state == .activeGoals
    }

    /// Whether a cycle just completed
    var isCycleComplete: Bool {
        state == .cycleComplete
    }

    // MARK: - Setup Progress (for locked state views)

    /// Whether baseline questions have been completed
    var hasCompletedBaselines: Bool {
        onboardingStatus?.questionnaireComplete ?? false
    }

    /// Whether lab results (biomarkers) have been entered by clinician
    var hasLabResults: Bool {
        onboardingStatus?.biomarkersEntered ?? false
    }

    /// Whether biometrics have been entered by clinician
    var hasBiometrics: Bool {
        onboardingStatus?.biometricsEntered ?? false
    }

    /// Whether to show status card in hamburger menu
    var shouldShowStatusCard: Bool {
        switch state {
        case .loading:
            return false
        case .activeGoals:
            // Show during active cycle with cycle progress
            return true
        default:
            return true
        }
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Load Journey State

    func loadState() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            state = .baselineCollection(completed: 0, total: 17)
            return
        }

        isLoading = true
        error = nil

        let patientId = userId.uuidString

        do {
            // Fetch patient onboarding status
            let statusResponse: [PatientOnboardingStatus] = try await supabase
                .from("patients")
                .select("questionnaire_complete, biomarkers_entered, biometrics_entered, recommendations_generated")
                .eq("patient_id", value: patientId)
                .limit(1)
                .execute()
                .value

            guard let status = statusResponse.first else {
                state = .baselineCollection(completed: 0, total: 17)
                isLoading = false
                return
            }

            self.onboardingStatus = status

            // Determine journey state based on status flags
            if status.recommendationsGenerated {
                // Check if cycle is complete
                let cycleComplete = await checkCycleComplete(patientId: patientId)
                if cycleComplete {
                    state = .cycleComplete
                } else {
                    state = .activeGoals
                    await loadCycleInfo(patientId: patientId)
                }
            } else if !status.questionnaireComplete {
                // Still collecting baseline questionnaires
                let baselineProgress = await loadBaselineProgress(patientId: patientId)
                state = .baselineCollection(completed: baselineProgress.completed, total: baselineProgress.total)
            } else if !status.biomarkersEntered {
                state = .awaitingLabs
            } else if !status.biometricsEntered {
                state = .awaitingBiometrics
            } else {
                state = .awaitingClinicianReview
            }

        } catch {
            self.error = error.localizedDescription
            print("[JourneyState] Error loading state: \(error)")
            // Default to demo mode on error
            state = .baselineCollection(completed: 0, total: 17)
        }

        isLoading = false
    }

    private func loadBaselineProgress(patientId: String) async -> (completed: Int, total: Int) {
        do {
            struct CategoryInfo: Decodable {
                let categoryId: String?
                let baselineType: String?

                enum CodingKeys: String, CodingKey {
                    case categoryId = "category_id"
                    case baselineType = "baseline_type"
                }
            }

            let questions: [CategoryInfo] = try await supabase
                .from("baseline_questions")
                .select("category_id, baseline_type")
                .eq("is_active", value: true)
                .execute()
                .value

            let categories = Set(questions.compactMap { $0.categoryId })
            let total = categories.count

            struct CompletedBaseline: Decodable {
                let baselineType: String

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                }
            }

            let completedBaselines: [CompletedBaseline] = try await supabase
                .from("patient_baseline_samples")
                .select("baseline_type")
                .eq("patient_id", value: patientId)
                .eq("is_current", value: true)
                .execute()
                .value

            let completedTypes = Set(completedBaselines.map { $0.baselineType })

            var completedCategories = 0
            for categoryId in categories {
                let categoryBaselineTypes = questions
                    .filter { $0.categoryId == categoryId }
                    .compactMap { $0.baselineType }

                if !categoryBaselineTypes.isEmpty && categoryBaselineTypes.allSatisfy({ completedTypes.contains($0) }) {
                    completedCategories += 1
                }
            }

            return (completed: completedCategories, total: max(total, 1))

        } catch {
            print("[JourneyState] Error loading baseline progress: \(error)")
            return (completed: 0, total: 17)
        }
    }

    private func checkCycleComplete(patientId: String) async -> Bool {
        // Check if current cycle has ended
        do {
            struct CycleInfo: Decodable {
                let endDate: String?
                let status: String?

                enum CodingKeys: String, CodingKey {
                    case endDate = "end_date"
                    case status
                }
            }

            let cycles: [CycleInfo] = try await supabase
                .from("patient_cycles")
                .select("end_date, status")
                .eq("patient_id", value: patientId)
                .order("start_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let cycle = cycles.first, cycle.status == "completed" {
                return true
            }

        } catch {
            print("[JourneyState] Error checking cycle: \(error)")
        }

        return false
    }

    private func loadCycleInfo(patientId: String) async {
        do {
            struct CycleInfo: Decodable {
                let cycleNumber: Int
                let startDate: String
                let endDate: String?

                enum CodingKeys: String, CodingKey {
                    case cycleNumber = "cycle_number"
                    case startDate = "start_date"
                    case endDate = "end_date"
                }
            }

            let cycles: [CycleInfo] = try await supabase
                .from("patient_cycles")
                .select("cycle_number, start_date, end_date")
                .eq("patient_id", value: patientId)
                .eq("status", value: "active")
                .order("start_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let cycle = cycles.first {
                self.currentCycleNumber = cycle.cycleNumber

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                if let startDate = dateFormatter.date(from: cycle.startDate) {
                    self.cycleStartDate = startDate

                    // Calculate current week
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.weekOfYear], from: startDate, to: Date())
                    self.cycleWeek = (components.weekOfYear ?? 0) + 1
                }

                if let endDateStr = cycle.endDate {
                    self.cycleEndDate = dateFormatter.date(from: endDateStr)
                }
            }

        } catch {
            print("[JourneyState] Error loading cycle info: \(error)")
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadState()
    }
}
