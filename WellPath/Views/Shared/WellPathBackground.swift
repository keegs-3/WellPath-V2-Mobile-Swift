//
//  WellPathBackground.swift
//  WellPath
//
//  Oura-inspired dark theme backgrounds with ambient glows.
//  Rich charcoal base with subtle radial bursts - premium feel.
//

import SwiftUI

// MARK: - App Color Constants

/// Core dark theme colors - premium charcoal palette
struct WellPathColors {
    /// Rich charcoal base - never pure black (#0D0F0E)
    static let backgroundBase = Color(red: 0.05, green: 0.06, blue: 0.055)

    /// Slightly elevated surface (#141716)
    static let surfaceElevated = Color(red: 0.08, green: 0.09, blue: 0.086)

    /// Card/component background (#1A1D1B)
    static let cardBackground = Color(red: 0.10, green: 0.115, blue: 0.105)

    /// Subtle highlight for interactive elements
    static let surfaceHighlight = Color(red: 0.12, green: 0.14, blue: 0.13)

    /// Brand green for accents
    static let brandGreen = Color(red: 0.34, green: 0.76, blue: 0.44)

    /// Deep teal for variety
    static let accentTeal = Color(red: 0.2, green: 0.5, blue: 0.5)

    /// Warm amber for highlights
    static let accentAmber = Color(red: 0.6, green: 0.4, blue: 0.2)
}

// MARK: - Oura-Style Ambient Background

/// Premium ambient background with single top-center glow (Oura-inspired)
struct WellPathAmbientBackground: View {
    var accentColor: Color = WellPathColors.brandGreen
    var intensity: CGFloat = 1.0

    var body: some View {
        let screenHeight = UIScreen.main.bounds.height

        ZStack {
            // Rich charcoal base
            WellPathColors.backgroundBase

            // Single top-center ambient glow
            RadialGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.15 * intensity),
                    accentColor.opacity(0.08 * intensity),
                    accentColor.opacity(0.03 * intensity),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: screenHeight * 0.6
            )
        }
        .ignoresSafeArea()
    }
}

/// Atmospheric dark background with subtle color gradient
struct WellPathBackground: View {
    let color: Color
    var intensity: CGFloat = 0.4

    var body: some View {
        let screenHeight = UIScreen.main.bounds.height

        ZStack {
            // Rich charcoal base
            WellPathColors.backgroundBase

            // Subtle ambient glow from bottom-left
            RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.06),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.2, y: 0.9),
                startRadius: 0,
                endRadius: screenHeight * 0.5
            )

            // Radial gradient from top center
            RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(intensity),
                    color.opacity(intensity * 0.5),
                    color.opacity(intensity * 0.2),
                    color.opacity(intensity * 0.05),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.7
            )
        }
        .ignoresSafeArea()
    }
}

/// Linear gradient variant - fades from top to bottom
struct WellPathLinearBackground: View {
    let color: Color
    var intensity: CGFloat = 0.5
    var fadeHeight: CGFloat = 400

    var body: some View {
        ZStack {
            // Rich charcoal base
            WellPathColors.backgroundBase

            // Linear gradient from top
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        color.opacity(intensity),
                        color.opacity(intensity * 0.6),
                        color.opacity(intensity * 0.3),
                        color.opacity(intensity * 0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)

                Spacer()
            }

            // Corner accent glow
            RadialGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.04),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.1, y: 0.8),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

/// Neutral dark background with soft ambient glows (no strong color)
struct WellPathNeutralBackground: View {
    var body: some View {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width

        ZStack {
            WellPathColors.backgroundBase

            // Very subtle green glow at bottom
            RadialGradient(
                gradient: Gradient(colors: [
                    WellPathColors.brandGreen.opacity(0.06),
                    WellPathColors.brandGreen.opacity(0.02),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.3, y: 0.95),
                startRadius: 0,
                endRadius: screenHeight * 0.4
            )

            // Soft teal accent top-right
            RadialGradient(
                gradient: Gradient(colors: [
                    WellPathColors.accentTeal.opacity(0.04),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.85, y: 0.15),
                startRadius: 0,
                endRadius: screenWidth * 0.5
            )
        }
        .ignoresSafeArea()
    }
}

/// Simple base background - charcoal with just a hint of depth
struct WellPathBaseBackground: View {
    var body: some View {
        ZStack {
            WellPathColors.backgroundBase

            // Very subtle center glow for depth
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.02),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.6
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Extension for Easy Application

extension View {
    /// Apply Oura-style ambient background with soft glows
    func wellPathAmbientBackground(color: Color = WellPathColors.brandGreen, intensity: CGFloat = 1.0) -> some View {
        self.background(WellPathAmbientBackground(accentColor: color, intensity: intensity))
    }

    /// Apply atmospheric background with accent color
    func wellPathBackground(color: Color, intensity: CGFloat = 0.4) -> some View {
        self.background(WellPathBackground(color: color, intensity: intensity))
    }

    /// Apply linear gradient background
    func wellPathLinearBackground(color: Color, intensity: CGFloat = 0.5, fadeHeight: CGFloat = 400) -> some View {
        self.background(WellPathLinearBackground(color: color, intensity: intensity, fadeHeight: fadeHeight))
    }

    /// Apply neutral dark background with subtle ambient glow
    func wellPathNeutralBackground() -> some View {
        self.background(WellPathNeutralBackground())
    }

    /// Apply simple charcoal base with hint of depth
    func wellPathBaseBackground() -> some View {
        self.background(WellPathBaseBackground())
    }
}

// MARK: - Previews

#Preview("Ambient Background (Oura-style)") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 80)
                    .overlay(
                        Text("Card \(i + 1)")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
    }
    .wellPathAmbientBackground()
}

#Preview("Radial Background") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 80)
                    .overlay(
                        Text("Card \(i + 1)")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
    }
    .wellPathBackground(color: .green)
}

#Preview("Neutral Background") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 80)
                    .overlay(
                        Text("Card \(i + 1)")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
    }
    .wellPathNeutralBackground()
}
