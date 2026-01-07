//
//  ChironAvatar.swift
//  WellPath
//
//  Chiron: The longevity assistant.
//  Named after the wisest centaur in Greek mythology, known for
//  teaching medicine and healing to heroes.
//
//  This component provides consistent branding for Chiron across
//  the app: tour, nudges, chat, and education modals.
//

import SwiftUI

/// Chiron avatar sizes for different contexts
enum ChironAvatarSize {
    case small      // 24pt - inline text, badges
    case medium     // 36pt - nudge cards, list items
    case large      // 44pt - tour bubble, chat header
    case hero       // 64pt - welcome screens, onboarding

    var dimension: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 36
        case .large: return 44
        case .hero: return 64
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 18
        case .large: return 22
        case .hero: return 32
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .small: return 1.5
        case .medium: return 2
        case .large: return 2.5
        case .hero: return 3
        }
    }
}

/// Chiron avatar style variants
enum ChironAvatarStyle {
    case filled     // Solid background (default)
    case outlined   // Border only
    case gradient   // Gradient background
}

/// The Chiron avatar component - displays the longevity assistant's branding
struct ChironAvatar: View {
    let size: ChironAvatarSize
    var style: ChironAvatarStyle = .filled
    var animate: Bool = false

    @State private var isAnimating = false

    // Chiron's brand colors
    private let chironGreen = Color(red: 0.2, green: 0.7, blue: 0.4)  // #33B366
    private let chironGreenLight = Color(red: 0.3, green: 0.8, blue: 0.5)
    private let chironGreenDark = Color(red: 0.15, green: 0.55, blue: 0.3)

    var body: some View {
        ZStack {
            // Background
            background

            // Icon - Stylized Chi (Χ) representing Chiron
            // Using a custom combination for distinctiveness
            chironSymbol
        }
        .frame(width: size.dimension, height: size.dimension)
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            Circle()
                .fill(chironGreen.opacity(0.15))

        case .outlined:
            Circle()
                .stroke(chironGreen, lineWidth: size.strokeWidth)

        case .gradient:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [chironGreenLight.opacity(0.2), chironGreen.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(chironGreen.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private var chironSymbol: some View {
        // Mountain path - references Chiron the centaur and WellPath's journey theme
        // Chiron lived on Mount Pelion and represents the path to optimal health
        Image(systemName: "mountain.2.fill")
            .font(.system(size: size.iconSize, weight: .medium))
            .foregroundColor(chironGreen)
            .scaleEffect(isAnimating && animate ? 1.1 : 1.0)
    }
}

/// Chiron avatar with name label for introductions
struct ChironAvatarWithName: View {
    let size: ChironAvatarSize
    var showSubtitle: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ChironAvatar(size: size, style: .gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chiron")
                    .font(size == .hero ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if showSubtitle {
                    Text("Your Longevity Assistant")
                        .font(size == .hero ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// Inline Chiron mention for text contexts
struct ChironMention: View {
    var body: some View {
        HStack(spacing: 4) {
            ChironAvatar(size: .small, style: .filled)
            Text("Chiron")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Previews

#Preview("Sizes") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            VStack {
                ChironAvatar(size: .small)
                Text("Small").font(.caption)
            }
            VStack {
                ChironAvatar(size: .medium)
                Text("Medium").font(.caption)
            }
            VStack {
                ChironAvatar(size: .large)
                Text("Large").font(.caption)
            }
            VStack {
                ChironAvatar(size: .hero)
                Text("Hero").font(.caption)
            }
        }
    }
    .padding()
}

#Preview("Styles") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            VStack {
                ChironAvatar(size: .large, style: .filled)
                Text("Filled").font(.caption)
            }
            VStack {
                ChironAvatar(size: .large, style: .outlined)
                Text("Outlined").font(.caption)
            }
            VStack {
                ChironAvatar(size: .large, style: .gradient)
                Text("Gradient").font(.caption)
            }
        }
    }
    .padding()
}

#Preview("With Name") {
    VStack(spacing: 24) {
        ChironAvatarWithName(size: .large)
        ChironAvatarWithName(size: .hero)
        ChironMention()
    }
    .padding()
}

#Preview("Animated") {
    ChironAvatar(size: .hero, style: .gradient, animate: true)
        .padding()
}
