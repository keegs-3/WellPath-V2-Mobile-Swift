//
//  TourMyDataScreen.swift
//  WellPath
//
//  My Data tab tour section: Shows data organization and navigation
//

import SwiftUI

struct TourMyDataScreen: View {
    var highlightMode: TourScreen = .dataOverview
    @ObservedObject private var tourManager = InteractiveTourManager.shared
    @State private var selectedSection: Int? = nil

    // Check if we're highlighting a specific section
    private var hasSpecificHighlight: Bool {
        [.dataSections, .dataFavorites, .dataCardNavigation, .dataDeepNavigation].contains(highlightMode)
    }

    var body: some View {
        ZStack {
            // Subtle gradient background matching real app
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.03),
                    Color(uiColor: .systemBackground).opacity(0.95),
                    Color(uiColor: .systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Data")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("All your health information in one place")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                    // Section cards (matching real MyDataLandingView)
                    TourLandingSectionCard(
                        title: "Health Pillars",
                        subtitle: "Nutrition, Sleep, Movement & more",
                        icon: "heart.circle.fill",
                        color: .green,
                        isHighlighted: highlightMode == .dataSections && selectedSection == 0
                    )
                    .opacity(dimOpacity(for: 0))
                    .onTapGesture {
                        if highlightMode == .dataSections {
                            selectedSection = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Jump to favorites explanation
                                tourManager.goToScreen(.dataFavorites)
                            }
                        } else if highlightMode == .dataCardNavigation {
                            selectedSection = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Jump to deep navigation
                                tourManager.goToScreen(.dataDeepNavigation)
                            }
                        }
                    }

                    TourLandingSectionCard(
                        title: "Markers & Metrics",
                        subtitle: "Biomarkers & Biometrics",
                        icon: "waveform.path.ecg",
                        color: .blue,
                        isHighlighted: highlightMode == .dataSections && selectedSection == 1
                    )
                    .opacity(dimOpacity(for: 1))
                    .onTapGesture {
                        if highlightMode == .dataSections {
                            selectedSection = 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataFavorites)
                            }
                        } else if highlightMode == .dataCardNavigation {
                            selectedSection = 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataDeepNavigation)
                            }
                        }
                    }

                    TourLandingSectionCard(
                        title: "Lifestyle Factors",
                        subtitle: "Substances & Mental Health",
                        icon: "leaf.fill",
                        color: .purple,
                        isHighlighted: highlightMode == .dataSections && selectedSection == 2
                    )
                    .opacity(dimOpacity(for: 2))
                    .onTapGesture {
                        if highlightMode == .dataSections {
                            selectedSection = 2
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataFavorites)
                            }
                        } else if highlightMode == .dataCardNavigation {
                            selectedSection = 2
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataDeepNavigation)
                            }
                        }
                    }

                    TourLandingSectionCard(
                        title: "Health Records",
                        subtitle: "History, Therapeutics & Screenings",
                        icon: "folder.fill",
                        color: .orange,
                        isHighlighted: highlightMode == .dataSections && selectedSection == 3
                    )
                    .opacity(dimOpacity(for: 3))
                    .onTapGesture {
                        if highlightMode == .dataSections {
                            selectedSection = 3
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataFavorites)
                            }
                        } else if highlightMode == .dataCardNavigation {
                            selectedSection = 3
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tourManager.goToScreen(.dataDeepNavigation)
                            }
                        }
                    }

                    // Favorites hint when highlighting favorites
                    if highlightMode == .dataFavorites {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Star any metric for quick access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                        .onTapGesture {
                            tourManager.nextStep()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }

    // Calculate opacity based on highlight mode - more subtle dimming
    private func dimOpacity(for index: Int) -> Double {
        if !hasSpecificHighlight {
            return 1.0 // No specific highlight, show all
        }
        if highlightMode == .dataSections {
            return 1.0
        }
        return 0.7 // Only slightly dimmed
    }
}

// Matching real LandingSectionCard from MyDataLandingView
struct TourLandingSectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isHighlighted ? Color.green : Color.clear, lineWidth: 3)
                .shadow(color: isHighlighted ? .green.opacity(0.5) : .clear, radius: 8)
        )
    }
}

#Preview {
    TourMyDataScreen(highlightMode: .dataSections)
}
