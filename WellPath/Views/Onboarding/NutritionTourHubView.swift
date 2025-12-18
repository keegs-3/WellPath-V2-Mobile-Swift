//
//  NutritionTourHubView.swift
//  WellPath
//
//  Navigable hub for Nutrition tour - shows all nutrition screens as a grid
//  Users can tap any screen to navigate there and answer baseline questions.
//

import SwiftUI
import Supabase

struct NutritionTourHubView: View {
    @StateObject private var viewModel = NutritionTourHubViewModel()
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress header
                    progressHeader

                    // Grid of nutrition screens
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.screens) { screen in
                            NavigationLink {
                                destinationView(for: screen)
                            } label: {
                                NutritionScreenCard(
                                    screen: screen,
                                    questionsAnswered: viewModel.questionsAnswered[screen.screenId] ?? 0,
                                    totalQuestions: viewModel.totalQuestions[screen.screenId] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Continue/Complete button
                    if viewModel.allQuestionsAnswered {
                        completeButton
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nutrition Basics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadScreensAndProgress()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Your Nutrition Baseline")
                        .font(.headline)
                    Text("Tell us about your typical eating habits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(viewModel.totalAnswered) of \(viewModel.totalQuestionsCount) questions answered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }

                ProgressView(value: viewModel.overallProgress)
                    .tint(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            // Mark nutrition tour as completed
            UserDefaults.standard.set(true, forKey: "nutrition_tour_completed")
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Complete Nutrition Setup")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func destinationView(for screen: TourScreen) -> some View {
        let pillar = "Healthful Nutrition"
        let color = Color.green

        switch screen.iosViewName {
        case "ProteinScreen":
            ProteinScreen(pillar: pillar, color: color)
        case "VegetablesScreen":
            VegetablesScreen(pillar: pillar, color: color)
        case "FruitsScreen":
            FruitsScreen(pillar: pillar, color: color)
        case "LegumesScreen":
            LegumesScreen(pillar: pillar, color: color)
        case "WholeGrainsScreen":
            WholeGrainsScreen(pillar: pillar, color: color)
        case "NutsSeedsScreen":
            NutsSeedsScreen(pillar: pillar, color: .brown)
        case "FatsScreen":
            FatsScreen(pillar: pillar, color: .orange)
        case "WaterScreen":
            WaterScreen(pillar: pillar, color: .cyan)
        case "CaffeineScreen":
            CaffeineScreen(pillar: pillar, color: .brown)
        case "MealPatternsScreen":
            MealPatternsScreen(pillar: pillar, color: .indigo)
        case "UltraProcessedScreen":
            UltraProcessedScreen(pillar: pillar, color: .red)
        default:
            Text("Screen not found: \(screen.iosViewName)")
        }
    }
}

// MARK: - Screen Card

struct NutritionScreenCard: View {
    let screen: TourScreen
    let questionsAnswered: Int
    let totalQuestions: Int

    private var isComplete: Bool {
        totalQuestions > 0 && questionsAnswered >= totalQuestions
    }

    private var hasQuestions: Bool {
        totalQuestions > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            // Icon with completion indicator
            ZStack(alignment: .topTrailing) {
                Image(systemName: screen.icon)
                    .font(.title)
                    .foregroundColor(isComplete ? .green : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isComplete ? Color.green.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    )

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white))
                        .offset(x: 4, y: -4)
                }
            }

            // Screen name
            Text(screen.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            // Progress indicator
            if hasQuestions {
                Text("\(questionsAnswered)/\(totalQuestions)")
                    .font(.caption2)
                    .foregroundColor(isComplete ? .green : .secondary)
            } else {
                Text("No questions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class NutritionTourHubViewModel: ObservableObject {
    @Published var screens: [TourScreen] = []
    @Published var questionsAnswered: [String: Int] = [:]
    @Published var totalQuestions: [String: Int] = [:]
    @Published var isLoading = true

    var totalAnswered: Int {
        questionsAnswered.values.reduce(0, +)
    }

    var totalQuestionsCount: Int {
        totalQuestions.values.reduce(0, +)
    }

    var overallProgress: Double {
        guard totalQuestionsCount > 0 else { return 0 }
        return Double(totalAnswered) / Double(totalQuestionsCount)
    }

    var allQuestionsAnswered: Bool {
        totalQuestionsCount > 0 && totalAnswered >= totalQuestionsCount
    }

    func loadScreensAndProgress() async {
        isLoading = true

        do {
            let client = SupabaseManager.shared.client

            // Load nutrition screens
            let screenData: [TourScreen] = try await client
                .from("onboarding_tour_screens")
                .select()
                .eq("tour_section", value: "nutrition")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            screens = screenData

            // Load question counts per screen
            for screen in screens {
                await loadQuestionsForScreen(screen.screenId)
            }

            // Load user's answered questions
            await loadAnsweredQuestions()

        } catch {
            print("Error loading nutrition tour data: \(error)")
        }

        isLoading = false
    }

    private func loadQuestionsForScreen(_ screenId: String) async {
        do {
            let client = SupabaseManager.shared.client

            struct QuestionCount: Decodable {
                let count: Int
            }

            // Get count of questions for this screen
            let questions: [TourQuestion] = try await client
                .from("survey_questions_base")
                .select("id, question_number, question_text, type, target_screen_id, display_order_in_screen, is_required")
                .eq("target_screen_id", value: screenId)
                .eq("is_active", value: true)
                .execute()
                .value

            totalQuestions[screenId] = questions.count

        } catch {
            print("Error loading questions for \(screenId): \(error)")
            totalQuestions[screenId] = 0
        }
    }

    private func loadAnsweredQuestions() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get all user's responses
            struct ResponseData: Decodable {
                let questionNumber: Decimal

                enum CodingKeys: String, CodingKey {
                    case questionNumber = "question_number"
                }
            }

            let responses: [ResponseData] = try await client
                .from("patient_survey_responses")
                .select("question_number")
                .eq("patient_id", value: userId.uuidString)
                .execute()
                .value

            let answeredNumbers = Set(responses.map { $0.questionNumber })

            // For each screen, count how many questions are answered
            for screen in screens {
                let screenQuestions = await getQuestionNumbersForScreen(screen.screenId)
                let answered = screenQuestions.filter { answeredNumbers.contains($0) }.count
                questionsAnswered[screen.screenId] = answered
            }

        } catch {
            print("Error loading answered questions: \(error)")
        }
    }

    private func getQuestionNumbersForScreen(_ screenId: String) async -> [Decimal] {
        do {
            let client = SupabaseManager.shared.client

            struct QuestionNumber: Decodable {
                let questionNumber: Decimal

                enum CodingKeys: String, CodingKey {
                    case questionNumber = "question_number"
                }
            }

            let questions: [QuestionNumber] = try await client
                .from("survey_questions_base")
                .select("question_number")
                .eq("target_screen_id", value: screenId)
                .eq("is_active", value: true)
                .execute()
                .value

            return questions.map { $0.questionNumber }
        } catch {
            return []
        }
    }
}

// MARK: - Preview

#Preview {
    NutritionTourHubView()
}
