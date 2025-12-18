//
//  UltraProcessedServingsView.swift
//  WellPath
//
//  Full view for Ultra-Processed Foods Servings metric (DISP_ULTRA_PROCESSED_SERVINGS).
//  Shows servings of ultra-processed foods (goal is to minimize).
//

import SwiftUI

struct UltraProcessedServingsView: View {
    let color: Color

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_ULTRA_PROCESSED_SERVINGS")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_ULTRA_PROCESSED_SERVINGS"
    private let metricName = "Ultra-Processed Foods"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Today's Intake")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showAboutModal = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(color)
                        }
                    }

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Servings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatValue(viewModel.todayValue))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(color)
                                Text("srv")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("<2/day")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Status indicator
                    if let todayValue = viewModel.todayValue {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(todayValue <= 2 ? MetricsUIConfig.tierGood : (todayValue <= 4 ? MetricsUIConfig.tierMedium : MetricsUIConfig.tierPoor))
                                .frame(width: 10, height: 10)
                            Text(todayValue <= 2 ? "Great! Keep minimizing processed foods" :
                                 (todayValue <= 4 ? "Moderate - try to reduce intake" : "High - consider whole food alternatives"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // What counts card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ultra-Processed Examples")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        foodRow(icon: "xmark.circle.fill", text: "Packaged snacks & chips", isGood: false)
                        foodRow(icon: "xmark.circle.fill", text: "Sugary cereals", isGood: false)
                        foodRow(icon: "xmark.circle.fill", text: "Soft drinks & energy drinks", isGood: false)
                        foodRow(icon: "xmark.circle.fill", text: "Processed meats (hot dogs, deli)", isGood: false)
                        foodRow(icon: "xmark.circle.fill", text: "Fast food items", isGood: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // Better alternatives card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Better Alternatives")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        foodRow(icon: "checkmark.circle.fill", text: "Fresh fruits & vegetables", isGood: true)
                        foodRow(icon: "checkmark.circle.fill", text: "Nuts & seeds", isGood: true)
                        foodRow(icon: "checkmark.circle.fill", text: "Whole grains", isGood: true)
                        foodRow(icon: "checkmark.circle.fill", text: "Homemade meals", isGood: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // CTA
                if viewModel.todayValue == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.3))

                        Text("Track your food to monitor ultra-processed intake")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            showingEntryForm = true
                        }) {
                            Label("Log Food", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(color)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.top)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Ultra-Processed")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: "DISP_ULTRA_PROCESSED_SERVINGS",
                    displayName: "Ultra-Processed Foods",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_ULTRA_PROCESSED",
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    @ViewBuilder
    private func foodRow(icon: String, text: String, isGood: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isGood ? MetricsUIConfig.tierGood : MetricsUIConfig.tierPoor)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func formatValue(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        if value >= 10 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    NavigationStack {
        UltraProcessedServingsView(color: .red)
    }
}
