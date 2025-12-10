//
//  AboutContentView.swift
//  WellPath
//
//  Shared component for displaying educational content (About, Health Impact, Quick Tips).
//  Consolidates duplicate aboutContentView implementations across the app.
//

import SwiftUI

/// Content data for the About view
struct AboutContent {
    let aboutText: String?
    let healthImpact: String?
    let quickTips: [String]?

    init(
        aboutText: String? = nil,
        healthImpact: String? = nil,
        quickTips: [String]? = nil
    ) {
        self.aboutText = aboutText
        self.healthImpact = healthImpact
        self.quickTips = quickTips
    }
}

/// Shared About content view with educational information
struct AboutContentView: View {
    let content: AboutContent
    let color: Color
    @Binding var showAbout: Bool
    var supportsMarkdown: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            scrollContent
            closeButton
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                aboutSection
                healthImpactSection
                quickTipsSection
            }
            .padding()
            .padding(.top, 40)
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        if let about = content.aboutText {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(icon: "info.circle.fill", title: "About")
                textContent(about)
            }
        }
    }

    @ViewBuilder
    private var healthImpactSection: some View {
        if let impact = content.healthImpact {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(icon: "heart.circle.fill", title: "Health Impact")
                textContent(impact)
            }
        }
    }

    @ViewBuilder
    private var quickTipsSection: some View {
        if let tips = content.quickTips, !tips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "lightbulb.circle.fill", title: "Quick Tips")
                tipsList(tips)
            }
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
    }

    @ViewBuilder
    private func textContent(_ text: String) -> some View {
        if supportsMarkdown, let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
                .foregroundColor(.secondary)
        } else {
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func tipsList(_ tips: [String]) -> some View {
        ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1).")
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                Text(tip)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var closeButton: some View {
        Button {
            withAnimation {
                showAbout = false
            }
        } label: {
            Image(systemName: "chart.bar")
                .font(.title3)
                .foregroundColor(color)
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
}

// MARK: - Loading/Error States Wrapper

/// Wrapper that handles loading and error states before showing content
struct AboutContentLoadingView<ViewModel: ObservableObject>: View {
    @ObservedObject var viewModel: ViewModel
    let color: Color
    @Binding var showAbout: Bool
    let isLoading: Bool
    let error: String?
    let content: AboutContent
    var supportsMarkdown: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else {
                        contentView
                    }
                }
                .padding()
                .padding(.top, 40)
            }

            closeButton
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading content...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Unable to load content")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var contentView: some View {
        VStack(spacing: 24) {
            if let about = content.aboutText {
                sectionView(icon: "info.circle.fill", title: "About", text: about)
            }
            if let impact = content.healthImpact {
                sectionView(icon: "heart.circle.fill", title: "Health Impact", text: impact)
            }
            if let tips = content.quickTips, !tips.isEmpty {
                tipsSection(tips)
            }
        }
    }

    private func sectionView(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            if supportsMarkdown, let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text(text)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.circle.fill")
                    .foregroundColor(color)
                Text("Quick Tips")
                    .font(.headline)
            }
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    Text(tip)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var closeButton: some View {
        Button {
            withAnimation {
                showAbout = false
            }
        } label: {
            Image(systemName: "chart.bar")
                .font(.title3)
                .foregroundColor(color)
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
}

#Preview("With Content") {
    AboutContentView(
        content: AboutContent(
            aboutText: "This metric tracks your daily protein intake, which is essential for muscle maintenance and repair.",
            healthImpact: "Adequate protein intake supports muscle mass, immune function, and healthy aging.",
            quickTips: [
                "Aim for 0.8-1g of protein per pound of body weight",
                "Spread intake across meals for optimal absorption",
                "Include a variety of protein sources"
            ]
        ),
        color: .blue,
        showAbout: .constant(true)
    )
}

#Preview("Empty Content") {
    AboutContentView(
        content: AboutContent(),
        color: .green,
        showAbout: .constant(true)
    )
}
