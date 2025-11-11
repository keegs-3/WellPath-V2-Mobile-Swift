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
    @State private var showQuickActions = false

    var body: some View {
        NavigationView {
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

                        // Tracked Metrics Navigation
                        NavigationLink(destination: TrackedMetricsListView()) {
                            TrackedMetricsButton()
                        }
                    }
                    .padding()
            }
            .background(
                ZStack {
                    // Background gradient
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.65),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.45),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.25),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)

                        Spacer()
                    }

                    // Large background logo
                    VStack {
                        HStack {
                            Spacer()
                            Image("white_grey")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .opacity(0.35)
                                .rotationEffect(.degrees(-15))
                                .offset(x: 40, y: 20)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showQuickActions = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }

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
            .sheet(isPresented: $showQuickActions) {
                QuickActionsView()
            }
            .task {
                await scoreViewModel.loadWellPathScore()
            }
        }
    }
}

struct TrackedMetricsButton: View {
    var body: some View {
        HStack(spacing: 20) {
            // Logo on the left
            ZStack {
                Circle()
                    .fill(Color(red: 0.78, green: 0.96, blue: 0.46))
                    .frame(width: 60, height: 60)

                Image("black_grey")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
            }

            Text("WellPath Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.9),
                    Color(white: 0.97).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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

                // Progress ring - Black
                // Cap at 0.995 to always show a tiny sliver
                Circle()
                    .trim(from: 0, to: min(CGFloat(score) / 100, 0.995))
                    .stroke(.black, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Score text - black
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
            }

            // Right side - Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("WellPath Score")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

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
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.9),
                    Color(white: 0.97).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
}
