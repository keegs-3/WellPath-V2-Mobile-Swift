//
//  TourNavigationScreen.swift
//  WellPath
//
//  Navigation overview: Shows tab bar highlights, plus button, hamburger menu
//

import SwiftUI

struct TourNavigationScreen: View {
    let highlightMode: TourScreen
    @ObservedObject private var tourManager = InteractiveTourManager.shared

    @State private var pulseAnimation = false
    @State private var showHamburgerMenu = false

    // Check if we're highlighting a specific tab
    private var hasTabHighlight: Bool {
        [.goalsTabIntro, .scoreTabIntro, .dataTabIntro, .plusButton, .hamburgerMenu].contains(highlightMode)
    }

    // Check if we should blur content
    private var shouldBlurContent: Bool {
        hasTabHighlight
    }

    var body: some View {
        ZStack {
            // REAL Goals tab background and content
            GoalsHeroBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hamburger menu button in top-left (like real app)
                HStack {
                    Button(action: {
                        if highlightMode == .hamburgerMenu {
                            showHamburgerMenu = true
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: highlightMode == .hamburgerMenu ? 2 : 0)
                            .scaleEffect(pulseAnimation && highlightMode == .hamburgerMenu ? 1.1 : 1.0)
                    )
                    .blur(radius: shouldBlurContent && highlightMode != .hamburgerMenu ? 3 : 0)
                    .opacity(shouldBlurContent && highlightMode != .hamburgerMenu ? 0.4 : 1.0)

                    Spacer()

                    Text("Goals")
                        .font(.headline)
                        .foregroundColor(.white)
                        .blur(radius: shouldBlurContent ? 3 : 0)
                        .opacity(shouldBlurContent ? 0.4 : 1.0)

                    Spacer()

                    // Spacer for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal)

                // Sample goal pills (blurred when focusing on navigation)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        TourGoalPill(icon: "fork.knife", label: "Protein", score: 75)
                        TourGoalPill(icon: "figure.walk", label: "Steps", score: 62)
                        TourGoalPill(icon: "bed.double.fill", label: "Sleep", score: 88)
                        TourGoalPill(icon: "dumbbell.fill", label: "Strength", score: 33)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .blur(radius: shouldBlurContent ? 4 : 0)
                .opacity(shouldBlurContent ? 0.3 : 1.0)

                // Real adherence arc (blurred when focusing on navigation)
                TourAdherenceArc(progress: 68, maxPotential: 92)
                    .padding(.top, 8)
                    .blur(radius: shouldBlurContent ? 4 : 0)
                    .opacity(shouldBlurContent ? 0.3 : 1.0)

                Spacer()

                // Highlighted tab bar at bottom
                highlightedTabBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Room for coach bubble
            }

            // Hamburger menu overlay
            if showHamburgerMenu {
                tourHamburgerMenuOverlay
            }
        }
    }

    // Simple hamburger menu preview
    private var tourHamburgerMenuOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showHamburgerMenu = false
                    tourManager.nextStep()
                }

            // Menu panel
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WellPath")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Cycle 1 • Week 3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.2))

                    // Menu items
                    VStack(spacing: 0) {
                        TourMenuRow(icon: "person.circle", label: "Profile")
                        TourMenuRow(icon: "gearshape", label: "Settings")
                        TourMenuRow(icon: "book.closed", label: "Learn")
                        TourMenuRow(icon: "questionmark.circle", label: "Help")
                    }

                    Spacer()

                    // Tap to continue hint
                    Text("Tap anywhere to continue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(width: 280)
                .background(Color(uiColor: .systemBackground))

                Spacer()
            }
            .transition(.move(edge: .leading))
        }
    }

    private var highlightedTabBar: some View {
        HStack(spacing: 24) {
            // Tab bar bubble (matching real LiquidGlassTabBar)
            HStack(spacing: 0) {
                // Goals tab - tappable, navigates to Goals section
                TourTabItem(
                    icon: "sun.max",
                    label: "Goals",
                    isHighlighted: highlightMode == .goalsTabIntro || highlightMode == .navigationOverview
                )
                .opacity(highlightMode == .scoreTabIntro || highlightMode == .dataTabIntro ? 0.4 : 1.0)
                .onTapGesture {
                    if highlightMode == .goalsTabIntro {
                        // Jump directly to Goals overview screen
                        tourManager.goToScreen(.goalsOverview)
                    }
                }

                // Score tab - tappable, navigates to Score section
                TourTabItem(
                    icon: "gauge.with.needle",
                    label: "Score",
                    isHighlighted: highlightMode == .scoreTabIntro
                )
                .opacity(highlightMode == .goalsTabIntro || highlightMode == .dataTabIntro ? 0.4 : 1.0)
                .onTapGesture {
                    if highlightMode == .scoreTabIntro {
                        // Jump directly to Score overview screen
                        tourManager.goToScreen(.scoreOverview)
                    }
                }

                // My Data tab - tappable, navigates to Data section
                TourTabItem(
                    icon: "list.clipboard",
                    label: "My Data",
                    isHighlighted: highlightMode == .dataTabIntro
                )
                .opacity(highlightMode == .goalsTabIntro || highlightMode == .scoreTabIntro ? 0.4 : 1.0)
                .onTapGesture {
                    if highlightMode == .dataTabIntro {
                        // Jump directly to Data overview screen
                        tourManager.goToScreen(.dataOverview)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.green, lineWidth: highlightMode == .navigationOverview ? 3 : 0)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .opacity(pulseAnimation ? 0.6 : 1.0)
            )
            .opacity(highlightMode == .plusButton ? 0.4 : 1.0)

            // Plus button (matching real LiquidGlassTabBar)
            Button(action: {
                if highlightMode == .plusButton {
                    tourManager.nextStep()
                }
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.green, lineWidth: highlightMode == .plusButton ? 3 : 0)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .opacity(pulseAnimation ? 0.6 : 1.0)
            )
            .opacity(hasTabHighlight && highlightMode != .plusButton ? 0.4 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

#Preview {
    TourNavigationScreen(highlightMode: .goalsTabIntro)
}
