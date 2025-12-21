//
//  ProteinScreen.swift
//  WellPath
//
//  Card-based layout for Protein metric.
//  Shows score card at top, then 3 cards: Amount, Type, Ratio.
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI
import Supabase

struct ProteinScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingWizard = false
    @State private var showingWizardHub = false
    @StateObject private var baselineViewModel = ProteinScreenBaselineViewModel()
    @StateObject private var scoreViewModel = ProteinScoreViewModel()

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    private var hasCompletedWizard: Bool {
        UserDefaults.standard.bool(forKey: "protein_wizard_completed")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Score card at top (if score exists) or wizard prompt
                if scoreViewModel.hasScore {
                    ProteinScoreCard(color: color, viewModel: scoreViewModel)
                } else if baselineViewModel.hasBaseline {
                    // Has baseline but no score yet - show baseline card
                    Button {
                        showingWizardHub = true
                    } label: {
                        ProteinBaselineSummaryCard(
                            color: color,
                            baselineAmount: baselineViewModel.baselineAmount,
                            baselineTypeScore: baselineViewModel.baselineTypeScore,
                            baselineRatio: baselineViewModel.baselineRatio
                        )
                    }
                    .buttonStyle(.plain)
                } else if !hasCompletedWizard {
                    // First-time wizard prompt
                    ProteinScoreEmptyCard(color: color) {
                        showingWizard = true
                    }
                }

                // Reusable card components
                ProteinAmountCard(color: color, pillar: pillar)
                ProteinTypeCard(color: color, pillar: pillar)
                ProteinRatioCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Protein")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Wizard/Hub button
                    Button {
                        if hasCompletedWizard {
                            showingWizardHub = true
                        } else {
                            showingWizard = true
                        }
                    } label: {
                        Image(systemName: "book.fill")
                    }

                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .protein)
        }
        .sheet(isPresented: $showingWizard) {
            ProteinWizardView()
        }
        .sheet(isPresented: $showingWizardHub) {
            ProteinWizardHubView()
        }
        .task {
            await baselineViewModel.loadData()
            await scoreViewModel.loadData()
        }
        .onChange(of: showingWizard) { _, isShowing in
            if !isShowing {
                // Reload data after wizard closes
                Task {
                    await baselineViewModel.loadData()
                    await scoreViewModel.loadData()
                }
            }
        }
        .onChange(of: showingWizardHub) { _, isShowing in
            if !isShowing {
                // Reload data after hub closes
                Task {
                    await baselineViewModel.loadData()
                    await scoreViewModel.loadData()
                }
            }
        }
    }

    // MARK: - Wizard Prompt Card

    private var wizardPromptCard: some View {
        Button {
            showingWizard = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Get Started with Protein")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Learn about tracking and set your baseline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Baseline ViewModel

@MainActor
class ProteinScreenBaselineViewModel: ObservableObject {
    // All 3 baseline values
    @Published var baselineAmount: Double?       // daily_protein_g
    @Published var baselineTypeScore: Double?    // protein_type_score
    @Published var baselineRatio: Double?        // daily_protein_ratio

    // Current data (for comparison if needed later)
    @Published var currentDailyAverage: Double?

    var hasBaseline: Bool {
        baselineAmount != nil || baselineTypeScore != nil || baselineRatio != nil
    }

    func loadData() async {
        async let baselineTask: () = loadBaselines()
        async let currentTask: () = loadCurrentData()

        _ = await (baselineTask, currentTask)
    }

    private func loadBaselines() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                }
            }

            // Load all protein-related baselines
            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .in("baseline_type", values: ["daily_protein_g", "protein_type_score", "daily_protein_ratio"])
                .execute()
                .value

            for baseline in baselines {
                switch baseline.baselineType {
                case "daily_protein_g":
                    baselineAmount = baseline.value
                case "protein_type_score":
                    baselineTypeScore = baseline.value
                case "daily_protein_ratio":
                    baselineRatio = baseline.value
                default:
                    break
                }
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    private func loadCurrentData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }

            struct SampleData: Decodable {
                let value: Double
                let canonicalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case value = "quantity_value"
                    case canonicalValue = "canonical_value"
                }
            }

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]

            let results: [SampleData] = try await client
                .from("patient_quantity_samples")
                .select("quantity_value, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .gte("aggregation_date", value: dateFormatter.string(from: weekAgo))
                .execute()
                .value

            if !results.isEmpty {
                let totalProtein = results.reduce(0.0) { $0 + ($1.canonicalValue ?? $1.value) }
                currentDailyAverage = totalProtein / Double(results.count)
            }
        } catch {
            print("Error loading current data: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ProteinScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
