//
//  HealthProfileWelcomeSheet.swift
//  WellPath
//
//  Multi-page onboarding tutorial for the Health Profile.
//  Explains why the profile matters and how to navigate it.
//

import SwiftUI

struct HealthProfileWelcomeSheet: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [WelcomePage] = [
        WelcomePage(
            icon: "heart.text.square.fill",
            iconColor: .blue,
            title: "Build Your Health Profile",
            subtitle: "Welcome to WellPath",
            description: "Your health profile helps us understand your unique lifestyle, habits, and health history so we can provide personalized insights and recommendations."
        ),
        WelcomePage(
            icon: "chart.bar.fill",
            iconColor: .green,
            title: "Power Your WellPath Score",
            subtitle: "Why This Matters",
            description: "Your responses help calculate your initial WellPath wellness score across 7 health pillars. As you track real data, your score becomes even more accurate."
        ),
        WelcomePage(
            icon: "square.grid.2x2.fill",
            iconColor: .purple,
            title: "8 Topics, Your Pace",
            subtitle: "How It Works",
            description: "The profile covers 8 health areas from nutrition to sleep to medical history. Take breaks whenever you need—your progress is saved automatically."
        ),
        WelcomePage(
            icon: "arrow.triangle.branch",
            iconColor: .orange,
            title: "Navigate Freely",
            subtitle: "Explore Your Way",
            description: "Jump between sections, skip around, and come back to questions anytime. Complete each section at your own pace over the next 1-2 weeks."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }

                // Buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
    }

    private func pageView(_ page: WelcomePage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundColor(page.iconColor)
            }

            // Text content
            VStack(spacing: 16) {
                Text(page.subtitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(page.iconColor)
                    .textCase(.uppercase)

                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Welcome Page Model

private struct WelcomePage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

#Preview {
    HealthProfileWelcomeSheet {
        print("Welcome complete")
    }
}
