//
//  BiomarkersList.swift
//  WellPath
//
//  List view for all biomarkers with search
//

import SwiftUI

struct BiomarkersList: View {
    @StateObject private var viewModel = MetricsViewModel()
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var filteredBiomarkers: [BiomarkerCardData] {
        if searchText.isEmpty {
            return viewModel.biomarkerCards
        }
        return viewModel.biomarkerCards.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search biomarkers", text: $searchText)
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
                    ProgressView("Loading biomarkers...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if filteredBiomarkers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "No biomarkers available" : "No matching biomarkers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredBiomarkers) { card in
                            NavigationLink(destination: BiomarkerDetailView(
                                name: card.name,
                                value: card.value,
                                status: card.status,
                                optimalRange: card.optimalRange,
                                trend: card.trend,
                                isBiometric: false
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
                                    isBiometric: false,
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
                // Purple gradient background for biomarkers
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.74, green: 0.56, blue: 0.94).opacity(0.65),
                            Color(red: 0.74, green: 0.56, blue: 0.94).opacity(0.45),
                            Color(red: 0.74, green: 0.56, blue: 0.94).opacity(0.25),
                            Color(red: 0.74, green: 0.56, blue: 0.94).opacity(0.1),
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
                        Image(systemName: "testtube.2")
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
        .navigationTitle("Biomarkers")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadBiomarkers()
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

struct BiomarkerCard: View {
    let name: String
    let value: String
    let numericValue: Double?
    let status: String
    let rangeName: String
    let optimalRange: String
    let trend: String
    let trendData: [Double]
    let statusColor: Color
    let isBiometric: Bool
    let rangeSegments: [RangeSegment]

    var metricColor: Color {
        if isBiometric {
            return Color(red: 0.40, green: 0.80, blue: 1.0) // Blue for biometrics
        } else {
            return Color(red: 0.74, green: 0.56, blue: 0.94) // Purple for biomarkers
        }
    }

    var metricIcon: String {
        if isBiometric {
            return "waveform.path.ecg" // Physical measurements
        } else {
            return "testtube.2" // Lab/blood tests
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left - Small Icon and Name
            HStack(spacing: 8) {
                Image(systemName: metricIcon)
                    .font(.system(size: 14))
                    .foregroundColor(metricColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(metricColor)
                        .lineLimit(1)

                    // Value with units below name
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Right - Status text, range indicator, and chevron
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    // Segmented range indicator
                    if let patientValue = numericValue, !rangeSegments.isEmpty {
                        RangeIndicatorView(
                            segments: rangeSegments,
                            patientValue: patientValue
                        )
                    } else {
                        // Fallback to simple dot if no range data
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                    }
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        BiomarkersList()
    }
}
