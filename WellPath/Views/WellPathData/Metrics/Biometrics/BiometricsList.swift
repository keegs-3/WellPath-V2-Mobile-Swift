//
//  BiometricsList.swift
//  WellPath
//
//  List view for all biometrics with search
//

import SwiftUI

struct BiometricsList: View {
    @StateObject private var viewModel = MetricsViewModel()
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    // Metrics that exist in both biometrics AND TrackedMetrics (hide from this list)
    private let duplicateMetrics = [
        "Steps/Day",
        "Deep Sleep",
        "REM Sleep",
        "Total Sleep",
        "Water Intake"
    ]

    var filteredBiometrics: [BiometricCardData] {
        // First filter out duplicates that exist in TrackedMetrics
        let uniqueBiometrics = viewModel.biometricCards.filter { card in
            !duplicateMetrics.contains(card.name)
        }

        // Then apply search filter if needed
        if searchText.isEmpty {
            return uniqueBiometrics
        }
        return uniqueBiometrics.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search biometrics", text: $searchText)
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)

            // List
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading biometrics...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if filteredBiometrics.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "No biometrics available" : "No matching biometrics")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredBiometrics) { card in
                            NavigationLink(destination: BiomarkerDetailView(
                                name: card.name,
                                value: card.value,
                                status: card.status,
                                optimalRange: card.optimalRange,
                                trend: card.trend,
                                isBiometric: true
                            )) {
                                BiomarkerCard(
                                    name: card.name,
                                    value: card.value,
                                    numericValue: card.numericValue,
                                    status: card.status,
                                    rangeName: card.rangeName,
                                    optimalRange: card.optimalRange,
                                    trend: card.trend,
                                    trendData: card.trendData,
                                    statusColor: getStatusColor(card.status),
                                    isBiometric: true,
                                    rangeSegments: card.rangeSegments
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .background(
            ZStack {
                // Blue gradient background for biometrics
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.65),
                            Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.45),
                            Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.25),
                            Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)

                    Spacer()
                }

                // Large background icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Biometrics")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadBiometrics()
        }
    }

    func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        BiometricsList()
    }
}
