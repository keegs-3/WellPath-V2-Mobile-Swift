//
//  TherapeuticsScreen.swift
//  WellPath
//
//  Main screen for Therapeutics category.
//  Shows cards for My Therapeutics, Supplements, Medications, Peptides, Hormones.
//  Follows WaterScreen pattern but without composite score (therapeutics aren't scored).
//

import SwiftUI

struct TherapeuticsScreen: View {
    let color: Color

    @State private var showingAddTherapeutic = false
    @State private var showingDataManagement = false
    @State private var showingWizard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // My Therapeutics - shows today's doses status
                MyTherapeuticsCard(color: color)

                // Suggested Therapeutics - based on patient scores
                SuggestedTherapeuticsCard(color: color)

                // Therapeutic type cards
                TherapeuticTypeCard(
                    title: "Supplements",
                    description: "View and manage your supplements",
                    icon: "leaf.fill",
                    therapeuticType: .supplement,
                    color: color
                )

                TherapeuticTypeCard(
                    title: "Medications",
                    description: "View and manage your medications",
                    icon: "pills.fill",
                    therapeuticType: .medication,
                    color: color
                )

                TherapeuticTypeCard(
                    title: "Peptides",
                    description: "View and manage your peptides",
                    icon: "waveform.path",
                    therapeuticType: .peptide,
                    color: color
                )

                TherapeuticTypeCard(
                    title: "Hormones",
                    description: "View and manage your hormones",
                    icon: "bolt.heart.fill",
                    therapeuticType: .hormone,
                    color: color
                )
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Therapeutics")
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
                    Button {
                        showingWizard = true
                    } label: {
                        Image(systemName: "book.fill")
                    }

                    Button {
                        showingAddTherapeutic = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTherapeutic) {
            TherapeuticsEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            // TODO: Create TherapeuticsDataManagementView
            Text("Therapeutics Data Management - Coming Soon")
        }
        .sheet(isPresented: $showingWizard) {
            TherapeuticsWizardView()
        }
    }
}

// MARK: - My Therapeutics Card

struct MyTherapeuticsCard: View {
    let color: Color

    @StateObject private var viewModel = MyTherapeuticsViewModel()

    var body: some View {
        MetricCardView(
            title: "My Therapeutics",
            color: color,
            metricId: "DISP_MY_THERAPEUTICS",
            pillar: "Core Care",
            cardId: "CARD_MY_THERAPEUTICS",
            sectionId: "NAV_CORE_CARE"
        ) {
            // Mini card content - shows today's doses status
            MyTherapeuticsMiniCard(viewModel: viewModel, color: color)
        } fullScreen: {
            MyTherapeuticsView(color: color)
        }
        .task {
            await viewModel.loadAll()
        }
    }
}

// MARK: - My Therapeutics Mini Card

struct MyTherapeuticsMiniCard: View {
    @ObservedObject var viewModel: MyTherapeuticsViewModel
    let color: Color

    /// Count expected doses for today
    private var expectedDosesToday: Int {
        var count = 0
        for therapeutic in viewModel.activeTherapeutics where therapeutic.trackAdherence == true {
            if therapeutic.timingMorning == true { count += 1 }
            if therapeutic.timingMidday == true { count += 1 }
            if therapeutic.timingEvening == true { count += 1 }
            if therapeutic.timingBedtime == true { count += 1 }
        }
        return count
    }

    /// Count logged doses for today
    private var loggedDosesToday: Int {
        viewModel.todaysLogs.filter { $0.taken }.count
    }

    private var allLogged: Bool {
        expectedDosesToday > 0 && loggedDosesToday >= expectedDosesToday
    }

    private var completionPercentage: Double {
        guard expectedDosesToday > 0 else { return 0 }
        return min(Double(loggedDosesToday) / Double(expectedDosesToday), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 50)
            } else if expectedDosesToday > 0 {
                // Show today's dose status
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(loggedDosesToday)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("of \(expectedDosesToday) logged")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: completionPercentage)
                            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)

                        Image(systemName: allLogged ? "checkmark" : "pills.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(allLogged ? .green : color)
                    }
                }
            } else {
                // Empty state - no therapeutics configured
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track Daily Doses")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Log your therapeutics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
            }
        }
    }
}

// MARK: - Therapeutic Type Card

struct TherapeuticTypeCard: View {
    let title: String
    let description: String
    let icon: String
    let therapeuticType: TherapeuticType
    let color: Color

    var body: some View {
        NavigationLink {
            TherapeuticsExploreView(therapeuticType: therapeuticType)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }

                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color.opacity(0.7))

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.25),
                                color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TherapeuticsScreen(color: Color(hex: "F4D284") ?? .yellow)
    }
}
