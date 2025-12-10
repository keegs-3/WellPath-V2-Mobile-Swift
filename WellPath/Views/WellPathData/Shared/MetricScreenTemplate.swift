//
//  MetricScreenTemplate.swift
//  WellPath
//
//  Universal template for ALL metric detail screens
//  Provides: gradient background, wave pattern, toolbar, about modal with chat, standard card backgrounds
//

import SwiftUI

// MARK: - Layout Constants

/// Standard layout constants for metric screens
/// Use these values to ensure consistent spacing across all metric views
///
/// The three-layer architecture pattern:
/// - Layer 1 (body): contentView + .metricScreenBackground(color:) + navigation modifiers
/// - Layer 2 (contentView): ScrollView > VStack with .padding(.vertical)
/// - Layer 3 (chartContent): VStack(spacing: 0) with .background(Color(uiColor: .systemGroupedBackground))
enum MetricScreenLayout {
    /// Top padding for period picker (D/W/M/6M/Y selector)
    static let pickerTopPadding: CGFloat = 16

    /// Top padding for chart header (metric values, info button)
    static let headerTopPadding: CGFloat = 12

    /// Top padding for chart content
    static let chartTopPadding: CGFloat = 16

    /// Bottom padding for chart content
    static let chartBottomPadding: CGFloat = 24

    /// Standard horizontal padding for content
    static let horizontalPadding: CGFloat = 16
}

// MARK: - Tab Template

/// Template for child tab views within a detail screen
/// Use when the parent already applies metricScreenBackground
/// (e.g., tabs within SleepDetailView, ProteinDetailView)
///
/// Usage:
/// ```swift
/// var body: some View {
///     MetricTabTemplate {
///         Picker("Period", selection: $selectedPeriod) { ... }
///             .pickerStyle(.segmented)
///             .padding(.horizontal)
///             .padding(.top, MetricScreenLayout.pickerTopPadding)
///
///         headerView
///             .padding(.top, MetricScreenLayout.headerTopPadding)
///
///         chartView
///             .padding(.top, MetricScreenLayout.chartTopPadding)
///             .padding(.bottom, MetricScreenLayout.chartBottomPadding)
///     }
/// }
/// ```
struct MetricTabTemplate<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

// MARK: - Screen Template

struct MetricScreenTemplate<Content: View>: View {
    let title: String
    let color: Color
    let metricId: String
    let content: Content
    let entrySheet: AnyView?
    let dataManagementSheet: AnyView?

    @StateObject private var educationLoader = BiometricEducationLoader()
    @State private var showAboutModal = false
    @State private var showChatModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false

    init(
        title: String,
        color: Color,
        metricId: String,
        @ViewBuilder content: () -> Content,
        entrySheet: AnyView? = nil,
        dataManagementSheet: AnyView? = nil
    ) {
        self.title = title
        self.color = color
        self.metricId = metricId
        self.content = content()
        self.entrySheet = entrySheet
        self.dataManagementSheet = dataManagementSheet
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    content
                }
                .padding(.vertical)
                .padding(.top, 20)
            }

            // Floating info button
            infoButton
        }
        .modifier(MetricScreenBackground(color: color))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAboutModal) {
            MetricAboutModal(
                title: title,
                color: color,
                metricId: metricId,
                sections: educationLoader.sections,
                isLoading: educationLoader.isLoading,
                onChatTapped: {
                    showAboutModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showChatModal = true
                    }
                }
            )
        }
        .sheet(isPresented: $showChatModal) {
            EducationQAModal(viewId: metricId, viewName: title, color: color)
        }
        .sheet(isPresented: $showAddEntry) {
            if let sheet = entrySheet { sheet }
        }
        .sheet(isPresented: $showDataManagement) {
            if let sheet = dataManagementSheet { sheet }
        }
        .task {
            await educationLoader.loadSections(for: metricId)
        }
    }

    private var infoButton: some View {
        Button { showAboutModal = true } label: {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundColor(color)
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if dataManagementSheet != nil {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDataManagement = true } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        if entrySheet != nil {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddEntry = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - About Modal

struct MetricAboutModal: View {
    let title: String
    let color: Color
    let metricId: String
    let sections: [EducationSection]
    let isLoading: Bool
    let onChatTapped: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isLoading {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if sections.isEmpty {
                        emptyState
                    } else {
                        ForEach(sections) { section in
                            educationSection(section)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("About \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onChatTapped()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Ask AI")
                        }
                        .foregroundColor(color)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No education content available")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tap 'Ask AI' to get personalized information about \(title).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onChatTapped()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Ask AI")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func educationSection(_ section: EducationSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: sectionIcon(section.sectionTitle))
                    .foregroundColor(color)
                Text(section.sectionTitle)
                    .font(.headline)
            }
            Text(section.sectionContent)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func sectionIcon(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("overview") || t.contains("about") { return "info.circle.fill" }
        if t.contains("longevity") || t.contains("health") { return "heart.circle.fill" }
        if t.contains("range") || t.contains("optimal") { return "chart.bar.fill" }
        if t.contains("tip") || t.contains("improve") { return "lightbulb.circle.fill" }
        if t.contains("misconception") { return "exclamationmark.triangle.fill" }
        return "doc.text.fill"
    }
}

// MARK: - Card Backgrounds
// Note: MetricScreenBackground ViewModifier is defined in MetricCardView.swift

struct MetricCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
    }
}

struct MetricChartCard<Content: View>: View {
    var title: String = "Trend"
    let content: Content

    init(title: String = "Trend", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            content
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }
}
