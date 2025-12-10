//
//  BiologicalAgeScreen.swift
//  WellPath
//
//  Biological Age tracking screen - TruDiagnostic integration
//

import SwiftUI

struct BiologicalAgeScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiologicalAgeViewModel()

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Biological Age")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if viewModel.hasResults {
                    // Show biological age results
                    biologicalAgeCard
                    ageComparisonCard
                    ageBreakdownSection
                } else {
                    // No results - show placeholder
                    noResultsView
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Biological Age")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .screen,
                    itemId: "SCREEN_BIOLOGICAL_AGE",
                    displayName: "Biological Age",
                    pillar: pillar,
                    cardId: nil,
                    sectionId: "NAV_BIOLOGICAL_AGE"
                )
            }
        }
        .task {
            await viewModel.loadBiologicalAge()
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 44))
                    .foregroundColor(color)
            }

            Text("No Biological Age Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Biological age testing (like TruDiagnostic) measures how fast your body is aging at the cellular level using epigenetic markers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "dna", text: "Epigenetic age analysis")
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Track biological age over time")
                featureRow(icon: "target", text: "Personalized longevity insights")
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Biological Age Card

    private var biologicalAgeCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biological Age")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", viewModel.biologicalAge ?? 0))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)

                        Text("years")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: screenIcon)
                        .font(.title)
                        .foregroundColor(color)
                }
            }

            if let testDate = viewModel.lastTestDate {
                HStack {
                    Spacer()
                    Text("Last tested: \(formatDate(testDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Age Comparison Card

    private var ageComparisonCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Age Comparison")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Chronological")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", viewModel.chronologicalAge ?? 0))
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    Text("Biological")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", viewModel.biologicalAge ?? 0))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ageDifferenceColor)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("Difference")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let diff = (viewModel.biologicalAge ?? 0) - (viewModel.chronologicalAge ?? 0)
                    Text(String(format: "%+.1f", diff))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ageDifferenceColor)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var ageDifferenceColor: Color {
        guard let bio = viewModel.biologicalAge, let chrono = viewModel.chronologicalAge else {
            return .primary
        }
        let diff = bio - chrono
        if diff < -2 {
            return .green
        } else if diff > 2 {
            return .red
        } else {
            return .primary
        }
    }

    // MARK: - Age Breakdown Section

    private var ageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Biological Age")
                .font(.headline)

            Text("Your biological age reflects how your body is aging at the cellular level. It's influenced by genetics, lifestyle, diet, exercise, sleep, and stress.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("A biological age younger than your chronological age suggests your lifestyle choices are having a positive effect on your longevity.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class BiologicalAgeViewModel: ObservableObject {
    @Published var biologicalAge: Double?
    @Published var chronologicalAge: Double?
    @Published var lastTestDate: Date?
    @Published var isLoading = false
    @Published var error: String?

    var hasResults: Bool {
        biologicalAge != nil
    }

    private let supabase = SupabaseManager.shared.client

    func loadBiologicalAge() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Check if patient has TruDiagnostic test results
            // For now, this is a placeholder - actual implementation would query
            // a biological_age_results table or similar

            // Load chronological age from patients table
            struct PatientAge: Codable {
                let dateOfBirth: String?

                enum CodingKeys: String, CodingKey {
                    case dateOfBirth = "date_of_birth"
                }
            }

            let patients: [PatientAge] = try await supabase
                .from("patients")
                .select("date_of_birth")
                .eq("patient_id", value: patientId)
                .limit(1)
                .execute()
                .value

            if let patient = patients.first, let dobString = patient.dateOfBirth {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let dob = formatter.date(from: dobString) {
                    let calendar = Calendar.current
                    let ageComponents = calendar.dateComponents([.year, .month], from: dob, to: Date())
                    let years = Double(ageComponents.year ?? 0)
                    let months = Double(ageComponents.month ?? 0)
                    chronologicalAge = years + (months / 12.0)
                }
            }

            // TODO: Load biological age from TruDiagnostic integration
            // For now, leave biologicalAge as nil to show placeholder

        } catch {
            self.error = error.localizedDescription
            print("Error loading biological age: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BiologicalAgeScreen(pillar: "Biological Age", color: Color.purple)
    }
}
