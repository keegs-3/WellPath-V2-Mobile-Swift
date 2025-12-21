//
//  DashboardView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var scoreViewModel = WellPathScoreViewModel()
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                        // WellPath Score
                        if scoreViewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = scoreViewModel.error {
                            VStack(spacing: 8) {
                                Text("WellPath Score")
                                    .font(.headline)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        } else {
                            NavigationLink(destination: WellPathOverviewView()) {
                                WellPathScoreCard(
                                    score: scoreViewModel.scorePercentage,
                                    calculatedDate: scoreViewModel.formattedCalculatedDate
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Weekly Goal Progress - TODO: Build curved visualization
                        // PillarChartCard()
                    }
                    .padding()
            }
            .metricScreenBackground(color: Color(red: 0.56, green: 0.82, blue: 0.31))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .task {
                await scoreViewModel.loadWellPathScore()
            }
        }
    }
}

struct WellPathScoreCard: View {
    let score: Int
    let calculatedDate: String

    var body: some View {
        HStack(spacing: 20) {
            // Left side - Ring
            ZStack {
                // Background ring - light gray
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)

                // Progress ring - Green
                // Cap at 0.995 to always show a tiny sliver
                Circle()
                    .trim(from: 0, to: min(CGFloat(score) / 100, 0.995))
                    .stroke(Color(red: 0.56, green: 0.82, blue: 0.31), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Score text - Green
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.56, green: 0.82, blue: 0.31))
            }

            // Right side - Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("WellPath Score")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Tooltip placeholder
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Text(calculatedDate)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
}
