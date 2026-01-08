//
//  TherapeuticsEntryView.swift
//  WellPath
//
//  Entry point for the Therapeutics section.
//  Shows "My Therapeutics" card and 4 Explore type cards.
//

import SwiftUI

struct TherapeuticsEntryView: View {
    var color: Color = Color(hex: "F4D284") ?? .yellow

    @State private var showingWizard = false
    @StateObject private var baselineChecker = TherapeuticsBaselineChecker()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // Baseline Setup Card - shows when not completed
                if !baselineChecker.isBaselineComplete {
                    TherapeuticsBaselineCard(color: color) {
                        showingWizard = true
                    }
                }

                // My Therapeutics - Main Card
                NavigationLink(destination: MyTherapeuticsView(color: color)) {
                    MyTherapeuticsMainCard(color: color)
                }
                .buttonStyle(.plain)

                // Explore Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Explore")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(TherapeuticType.primaryCases) { type in
                            NavigationLink(destination: TherapeuticsExploreView(therapeuticType: type)) {
                                ExploreTypeCard(type: type)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Therapeutics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingWizard = true
                } label: {
                    Image(systemName: "book.fill")
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            TherapeuticsWizardView()
        }
        .task {
            await baselineChecker.checkBaseline()
        }
        .onChange(of: showingWizard) { _, isShowing in
            if !isShowing {
                // Refresh baseline status when wizard closes
                Task {
                    await baselineChecker.checkBaseline()
                }
            }
        }
        }
    }
}

// MARK: - Baseline Checker

@MainActor
class TherapeuticsBaselineChecker: ObservableObject {
    @Published var isBaselineComplete = false

    private let supabase = SupabaseManager.shared.client

    func checkBaseline() async {
        do {
            let patientId = try await supabase.auth.session.user.id

            // Check if patient has completed therapeutics baseline
            // This is stored as a baseline sample with type 'therapeutics_baseline_complete'
            struct BaselineCheck: Codable {
                let id: UUID
            }

            let results: [BaselineCheck] = try await supabase
                .from("patient_baseline_samples")
                .select("id")
                .eq("patient_id", value: patientId)
                .eq("baseline_type", value: "therapeutics_baseline_complete")
                .eq("is_current", value: true)
                .limit(1)
                .execute()
                .value

            isBaselineComplete = !results.isEmpty
        } catch {
            print("TherapeuticsBaselineChecker: Error - \(error)")
            isBaselineComplete = false
        }
    }

    func markBaselineComplete() async {
        do {
            let patientId = try await supabase.auth.session.user.id

            struct BaselineInsert: Codable {
                let patientId: String
                let baselineType: String
                let value: Double
                let source: String
                let isCurrent: Bool

                enum CodingKeys: String, CodingKey {
                    case patientId = "patient_id"
                    case baselineType = "baseline_type"
                    case value
                    case source
                    case isCurrent = "is_current"
                }
            }

            try await supabase
                .from("patient_baseline_samples")
                .insert(BaselineInsert(
                    patientId: patientId.uuidString,
                    baselineType: "therapeutics_baseline_complete",
                    value: 1,
                    source: "onboarding",
                    isCurrent: true
                ))
                .execute()

            isBaselineComplete = true
        } catch {
            print("TherapeuticsBaselineChecker: Error marking complete - \(error)")
        }
    }
}

// MARK: - Baseline Card

struct TherapeuticsBaselineCard: View {
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Get Started with Therapeutics")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Learn how to track your medications & supplements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - My Therapeutics Main Card

struct MyTherapeuticsMainCard: View {
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundColor(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("My Therapeutics")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Track & log your daily doses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Explore Type Card

struct ExploreTypeCard: View {
    let type: TherapeuticType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(type.color)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayNamePlural)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(countLabel(for: type))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func countLabel(for type: TherapeuticType) -> String {
        switch type {
        case .medication: return "152 available"
        case .supplement: return "166 available"
        case .peptide: return "52 available"
        case .hormone: return "26 available"
        case .other: return "Browse"
        }
    }
}

#Preview {
    NavigationStack {
        TherapeuticsEntryView()
    }
}
