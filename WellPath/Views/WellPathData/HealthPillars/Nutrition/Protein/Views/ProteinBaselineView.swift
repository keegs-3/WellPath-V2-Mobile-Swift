//
//  ProteinBaselineView.swift
//  WellPath
//
//  Baseline setup for protein. Shows questions, educational content, and saves to patient_baseline_samples.
//  Can be accessed from: 1) Wizard during onboarding, 2) Book icon on ProteinScreen
//

import SwiftUI
import Supabase

struct ProteinBaselineView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProteinBaselineViewModel()

    let color: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        // Questions
                        questionsSection

                        // Save button
                        saveButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Protein Baseline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadQuestions()
            }
            .alert("Baseline Saved", isPresented: $viewModel.showSaveSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your protein baseline has been saved.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: "fish.fill")
                    .font(.title)
                    .foregroundColor(color)
            }

            Text("Set Your Protein Baseline")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Tell us about your typical protein intake. This helps us calculate your starting score and track improvements.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.questions) { question in
                BaselineQuestionCard(
                    question: question,
                    value: viewModel.responses[question.questionId]?.value,
                    onValueChanged: { newValue in
                        viewModel.setResponse(newValue, for: question)
                    },
                    color: color
                )
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveBaselines()
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isSaving ? "Saving..." : "Save Baseline")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSave ? color : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .padding(.top)
    }
}

// MARK: - Question Card

struct BaselineQuestionCard: View {
    let question: BaselineQuestion
    let value: Double?
    let onValueChanged: (Double?) -> Void
    let color: Color

    @State private var textValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            Text(question.questionText)
                .font(.subheadline)
                .fontWeight(.medium)

            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Input
            HStack {
                TextField(question.placeholder ?? "Enter value", text: $textValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: textValue) { _, newValue in
                        if let doubleValue = Double(newValue) {
                            onValueChanged(doubleValue)
                        } else if newValue.isEmpty {
                            onValueChanged(nil)
                        }
                    }

                Text(question.unitLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if value != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if let value = value {
                textValue = formatValue(value)
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - ViewModel

@MainActor
class ProteinBaselineViewModel: ObservableObject {
    @Published var questions: [BaselineQuestion] = []
    @Published var responses: [String: BaselineResponse] = [:]
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var showSaveSuccess = false

    var canSave: Bool {
        // At least one response entered
        responses.values.contains { $0.hasValue }
    }

    func loadQuestions() async {
        isLoading = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load protein questions
            let loadedQuestions: [BaselineQuestion] = try await client
                .from("baseline_questions")
                .select()
                .eq("category_id", value: "CAT_PROTEIN")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            questions = loadedQuestions

            // Load existing baselines
            let baselineTypes = loadedQuestions.compactMap { $0.baselineType }
            guard !baselineTypes.isEmpty else {
                isLoading = false
                return
            }

            struct ExistingBaseline: Decodable {
                let baselineType: String
                let value: Double
                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                }
            }

            let existing: [ExistingBaseline] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .in("baseline_type", values: baselineTypes)
                .execute()
                .value

            // Map to responses
            for baseline in existing {
                if let question = questions.first(where: { $0.baselineType == baseline.baselineType }) {
                    responses[question.questionId] = BaselineResponse(
                        questionId: question.questionId,
                        baselineType: baseline.baselineType,
                        value: baseline.value
                    )
                }
            }

        } catch {
            print("ProteinBaselineViewModel: Error loading questions - \(error)")
        }

        isLoading = false
    }

    func setResponse(_ value: Double?, for question: BaselineQuestion) {
        guard let baselineType = question.baselineType else { return }

        if let value = value {
            responses[question.questionId] = BaselineResponse(
                questionId: question.questionId,
                baselineType: baselineType,
                value: value
            )
        } else {
            responses.removeValue(forKey: question.questionId)
        }
    }

    func saveBaselines() async {
        isSaving = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let today = dateFormatter.string(from: Date())

            for (_, response) in responses where response.hasValue {
                let record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string(response.baselineType),
                    "value": .double(response.value!),
                    "source": .string("wizard"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(record)
                    .execute()
            }

            showSaveSuccess = true

        } catch {
            print("ProteinBaselineViewModel: Error saving baselines - \(error)")
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    ProteinBaselineView(color: .green)
}
