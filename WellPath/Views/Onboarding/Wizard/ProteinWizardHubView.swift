//
//  ProteinWizardHubView.swift
//  WellPath
//
//  Hub view for protein baseline management.
//  Shows current baseline and allows updates.
//

import SwiftUI
import Supabase

struct ProteinWizardHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProteinWizardHubViewModel()

    private let color = MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status header
                    statusHeader

                    // Baseline card - navigates to update/history flow
                    NavigationLink {
                        ProteinBaselineUpdateFlow()
                    } label: {
                        ProteinBaselineSummaryCard(
                            color: color,
                            baselineAmount: viewModel.baselineAmount,
                            baselineTypeScore: viewModel.baselineTypeScore,
                            baselineRatio: viewModel.baselineRatio
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Protein Baseline")
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
            await viewModel.loadData()
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: "fish.fill")
                    .font(.title)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Protein Baseline")
                    .font(.headline)

                if viewModel.hasBaseline {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Baseline set")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                } else {
                    Text("Set your protein targets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class ProteinWizardHubViewModel: ObservableObject {
    @Published var baselineAmount: Double?
    @Published var baselineTypeScore: Double?
    @Published var baselineRatio: Double?
    @Published var isLoading = false

    var hasBaseline: Bool {
        baselineAmount != nil || baselineTypeScore != nil || baselineRatio != nil
    }

    func loadData() async {
        isLoading = true
        await loadBaselines()
        isLoading = false
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

            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
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
}

// MARK: - Preview

#Preview("Hub - Completed") {
    ProteinWizardHubView()
}
