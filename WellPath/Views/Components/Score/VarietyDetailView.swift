//
//  VarietyDetailView.swift
//  WellPath
//
//  Database-driven variety score visualization.
//  Shows count (number of distinct types) toward target.
//  Used for: variety scores (vegetables_variety_score, fruits_variety_score, etc.)
//

import SwiftUI
import Supabase

// MARK: - Models

struct VarietyThresholdData: Codable {
    let id: UUID
    let thresholdKey: String
    let displayName: String?
    let targetValue: Double  // Target count
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case thresholdKey = "threshold_key"
        case displayName = "display_name"
        case targetValue = "target_value"
        case displayOrder = "display_order"
    }
}

/// Individual type with its consumed amount
struct VarietyTypeData: Identifiable {
    let id: String  // reference_key
    let displayName: String
    let value: Double
    let percentage: Double
}

// MARK: - ViewModel

@MainActor
class VarietyDetailViewModel: ObservableObject {
    @Published var threshold: VarietyThresholdData?
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load variety threshold for a score type
    func loadVarietyConfig(scoreType: String) async {
        isLoading = true
        error = nil

        do {
            let results: [VarietyThresholdData] = try await supabase
                .from("scoring_thresholds")
                .select("id, threshold_key, display_name, target_value, display_order")
                .eq("score_type", value: scoreType)
                .eq("threshold_type", value: "variety")
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            threshold = results.first
        } catch {
            self.error = error.localizedDescription
            print("Error loading variety config: \(error)")
        }

        isLoading = false
    }

    /// Build display data for types
    func buildTypeDisplayData(
        typeValues: [String: Double],
        displayNames: [String: String]
    ) -> [VarietyTypeData] {
        let total = typeValues.values.reduce(0, +)
        guard total > 0 else { return [] }

        return typeValues
            .filter { $0.value > 0 }
            .map { key, value in
                VarietyTypeData(
                    id: key,
                    displayName: displayNames[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized,
                    value: value,
                    percentage: (value / total) * 100
                )
            }
            .sorted { $0.value > $1.value }
    }
}

// MARK: - View

struct VarietyDetailView: View {
    let title: String
    let scoreType: String
    let typeValues: [String: Double]  // type_key -> value (grams, servings, etc.)
    let typeDisplayNames: [String: String]  // type_key -> display name
    let unit: String
    let score: Int?
    let color: Color

    @StateObject private var viewModel = VarietyDetailViewModel()

    init(
        title: String,
        scoreType: String,
        typeValues: [String: Double],
        typeDisplayNames: [String: String] = [:],
        unit: String = "g",
        score: Int? = nil,
        color: Color = .green
    ) {
        self.title = title
        self.scoreType = scoreType
        self.typeValues = typeValues
        self.typeDisplayNames = typeDisplayNames
        self.unit = unit
        self.score = score
        self.color = color
    }

    private var actualCount: Int {
        typeValues.values.filter { $0 > 0 }.count
    }

    private var targetCount: Int {
        Int(viewModel.threshold?.targetValue ?? 3)
    }

    private var typeDisplayData: [VarietyTypeData] {
        viewModel.buildTypeDisplayData(typeValues: typeValues, displayNames: typeDisplayNames)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(title)
                .font(.headline)

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                // Count section
                countSection

                // Types list
                if !typeDisplayData.isEmpty {
                    typesSection
                }

                // Score display
                if let score = score {
                    HStack {
                        Spacer()
                        Text("Variety Score: \(score)/100")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(for: score))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await viewModel.loadVarietyConfig(scoreType: scoreType)
        }
    }

    // MARK: - Count Section

    private var countSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Count")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(actualCount)")
                        .fontWeight(.bold)
                        .foregroundColor(countColor)
                    Text("of \(targetCount) types")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Actual fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(countColor)
                        .frame(width: geometry.size.width * min(1.0, Double(actualCount) / Double(targetCount)), height: 8)

                    // Target marker (at 100%)
                    VStack(spacing: 0) {
                        Triangle()
                            .fill(Color.primary)
                            .frame(width: 6, height: 3)
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 1.5, height: 12)
                    }
                    .offset(x: geometry.size.width - 3, y: -3)
                }
            }
            .frame(height: 16)

            // Status
            HStack {
                if actualCount >= targetCount {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Target reached!")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("\(targetCount - actualCount) more type\(targetCount - actualCount == 1 ? "" : "s") to reach target")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
    }

    private var countColor: Color {
        let ratio = Double(actualCount) / Double(targetCount)
        if ratio >= 1.0 { return .green }
        else if ratio >= 0.66 { return .yellow }
        else if ratio >= 0.33 { return .orange }
        else { return .red }
    }

    // MARK: - Types Section

    private var typesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Types consumed")
                .font(.subheadline)
                .fontWeight(.medium)

            // Grid of type pills
            FlowLayout(spacing: 8) {
                ForEach(typeDisplayData) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        Text(type.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.1))
                    .cornerRadius(16)
                }
            }
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Compact Variant
// Note: Uses FlowLayout from BiomarkerAboutModal.swift

struct VarietyCompactView: View {
    let count: Int
    let target: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)/\(target)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(count >= target ? .green : .orange)
            Text("types")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            VarietyDetailView(
                title: "Vegetable Variety",
                scoreType: "vegetables_variety_score",
                typeValues: [
                    "carrot": 50,
                    "broccoli": 45,
                    "spinach": 30,
                    "tomato": 25,
                    "bell_pepper": 20
                ],
                typeDisplayNames: [
                    "carrot": "Carrots",
                    "broccoli": "Broccoli",
                    "spinach": "Spinach",
                    "tomato": "Tomatoes",
                    "bell_pepper": "Bell Peppers"
                ],
                unit: "g",
                score: 92,
                color: .green
            )

            VarietyDetailView(
                title: "Fruit Variety",
                scoreType: "fruits_variety_score",
                typeValues: [
                    "apple": 100,
                    "banana": 10
                ],
                typeDisplayNames: [
                    "apple": "Apples",
                    "banana": "Bananas"
                ],
                unit: "g",
                score: 45,
                color: .orange
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
