//
//  TobaccoStreakView.swift
//  WellPath
//
//  Database-driven view for tracking smoke-free streak.
//  Loads about content from display_views table.
//

import SwiftUI

struct TobaccoStreakView: View {
    let color: Color
    @StateObject private var viewModel = TobaccoTrackingViewModel()
    @StateObject private var metricViewModel = StandardMetricViewModel(metricId: "DISP_TOBACCO_STREAK")
    @State private var showingQuitDatePicker = false
    @State private var selectedQuitDate = Date()
    @State private var showAboutModal = false

    private let metricId = "DISP_TOBACCO_STREAK"
    private let metricName = "Tobacco Streak"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Smoke-Free Streak
                streakSection

                // Action Buttons
                actionButtons

                // Health Benefits
                healthBenefitsSection
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Smoke-Free Streak")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAboutModal = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingQuitDatePicker) {
            QuitDatePickerSheet(viewModel: viewModel, selectedDate: $selectedQuitDate)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadHistory()
            await metricViewModel.loadPrimaryScreen()
        }
    }

    private var streakSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(viewModel.currentStreak > 0 ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 140, height: 140)

                VStack(spacing: 4) {
                    if viewModel.currentStreak > 0 {
                        Text("\(viewModel.currentStreak)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.green)
                        Text("days smoke-free")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "smoke.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Start your quit journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let quitDate = viewModel.quitDate {
                Text("Quit date: \(quitDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Milestones
            if viewModel.currentStreak > 0 {
                HStack(spacing: 20) {
                    MilestoneIndicator(days: 1, current: viewModel.currentStreak, label: "1 Day")
                    MilestoneIndicator(days: 7, current: viewModel.currentStreak, label: "1 Week")
                    MilestoneIndicator(days: 30, current: viewModel.currentStreak, label: "1 Month")
                    MilestoneIndicator(days: 365, current: viewModel.currentStreak, label: "1 Year")
                }
            }
        }
        .padding(.top, 20)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.currentStreak == 0 {
                Button {
                    showingQuitDatePicker = true
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Set Quit Date")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            } else {
                Button {
                    Task { await viewModel.resetQuitDate() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Streak (Relapsed)")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }

    private var healthBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Benefits of Quitting")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(time: "20 minutes", benefit: "Heart rate drops")
                BenefitRow(time: "12 hours", benefit: "Carbon monoxide normalizes")
                BenefitRow(time: "2-12 weeks", benefit: "Circulation improves")
                BenefitRow(time: "1-9 months", benefit: "Coughing decreases")
                BenefitRow(time: "1 year", benefit: "Heart disease risk halves")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Helper Views

struct MilestoneIndicator: View {
    let days: Int
    let current: Int
    let label: String

    var isAchieved: Bool { current >= days }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isAchieved ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)

                if isAchieved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct BenefitRow: View {
    let time: String
    let benefit: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(time)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .frame(width: 80, alignment: .leading)
            Text(benefit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuitDatePickerSheet: View {
    @ObservedObject var viewModel: TobaccoTrackingViewModel
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("When did you quit smoking?") {
                    DatePicker("Quit Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section {
                    Text("Select the date you stopped smoking to start tracking your smoke-free streak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Set Quit Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.setQuitDate(selectedDate)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TobaccoStreakView(color: .orange)
    }
}
