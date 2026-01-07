//
//  BiomarkerAboutModal.swift
//  WellPath
//
//  Universal modal view for metric education content
//  Shows expandable About, Longevity Impact, Optimal Ranges,
//  Common Misconceptions, Related Markers, Quick Tips, and Chat
//
//  Used by ALL metric views: biomarkers, biometrics, nutrition, sleep, etc.
//

import SwiftUI
import Supabase

/// Universal education modal for any metric type
/// Loads content from education_static_content table via view_id
struct MetricEducationModal: View {
    let viewId: String
    let metricName: String
    let color: Color
    @Binding var isPresented: Bool

    @StateObject private var loader = MetricEducationContentLoader()
    @State private var showChatModal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loader.isLoading {
                        loadingView
                    } else if let content = loader.content {
                        educationContent(content)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("About \(metricName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChatModal = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(color)
                    }
                }
            }
            .sheet(isPresented: $showChatModal) {
                EducationQAModal(viewId: viewId, viewName: metricName, color: color)
            }
        }
        .task {
            await loader.loadContent(for: viewId)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Educational content for \(metricName) will be available soon.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Education Content

    @ViewBuilder
    private func educationContent(_ content: BiomarkerEducationContent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // About Section (expandable)
            if content.aboutShort != nil || content.aboutFull != nil {
                ExpandableEducationSection(
                    title: "About",
                    icon: "info.circle.fill",
                    shortContent: content.aboutShort,
                    fullContent: content.aboutFull,
                    color: color
                )
            }

            // Longevity Impact (expandable)
            if content.longevityImpactShort != nil || content.longevityImpactFull != nil {
                ExpandableEducationSection(
                    title: "Longevity Impact",
                    icon: "heart.fill",
                    shortContent: content.longevityImpactShort,
                    fullContent: content.longevityImpactFull,
                    color: color
                )
            }

            // Optimal Ranges
            if let optimalRanges = content.optimalRanges, !optimalRanges.isEmpty {
                EducationInfoSection(
                    title: "Optimal Ranges",
                    icon: "chart.bar.fill",
                    content: optimalRanges,
                    color: color
                )
            }

            // Common Misconceptions
            if let misconceptions = content.commonMisconceptions, !misconceptions.isEmpty {
                EducationInfoSection(
                    title: "Common Misconceptions",
                    icon: "lightbulb.fill",
                    content: misconceptions,
                    color: color
                )
            }

            // Related Markers
            if let relatedMarkers = content.relatedMarkers, !relatedMarkers.isEmpty {
                RelatedMarkersSection(
                    markers: relatedMarkers,
                    color: color
                )
            }

            // Quick Tips
            if let quickTips = content.quickTips, !quickTips.isEmpty {
                QuickTipsSection(
                    tips: quickTips,
                    color: color
                )
            }

            // Chat prompt
            chatPromptSection
        }
    }

    private var chatPromptSection: some View {
        Button {
            showChatModal = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Have questions?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("Ask your Personal Longevity Guide")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expandable Education Section

struct ExpandableEducationSection: View {
    let title: String
    let icon: String
    let shortContent: String?
    let fullContent: String?
    let color: Color

    @State private var isExpanded = false

    private var hasExpandableContent: Bool {
        shortContent != nil && fullContent != nil && shortContent != fullContent
    }

    private var displayContent: String {
        if isExpanded, let full = fullContent {
            return full
        }
        return shortContent ?? fullContent ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if hasExpandableContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.caption)
                            .foregroundColor(color)
                    }
                }
            }

            // Content
            Text(displayContent)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Education Info Section (non-expandable)

struct EducationInfoSection: View {
    let title: String
    let icon: String
    let content: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Related Markers Section

struct RelatedMarkersSection: View {
    let markers: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text("Related Markers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            FlowLayout(spacing: 8) {
                ForEach(markers, id: \.self) { marker in
                    Text(marker)
                        .font(.caption)
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.1))
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Tips Section

struct QuickTipsSection: View {
    let tips: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text("Quick Tips")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(color)
                            .frame(width: 20, alignment: .trailing)

                        Text(tip)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)

                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                size.width = max(size.width, currentX)
            }

            size.height = currentY + lineHeight
        }
    }
}

// MARK: - Content Loader

@MainActor
class MetricEducationContentLoader: ObservableObject {
    @Published var content: MetricEducationContent?
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadContent(for viewId: String) async {
        isLoading = true
        error = nil

        do {
            // Query education_static_content directly
            let results: [EducationStaticContent] = try await supabase
                .from("education_static_content")
                .select()
                .eq("view_id", value: viewId)
                .eq("is_published", value: true)
                .limit(1)
                .execute()
                .value

            if let staticContent = results.first {
                content = MetricEducationContent(from: staticContent)
                print("✅ Loaded education content for \(viewId)")
            } else {
                print("⚠️ No education content found for \(viewId)")
            }

        } catch {
            self.error = error.localizedDescription
            print("❌ Error loading education content: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Content Model

struct MetricEducationContent {
    let aboutShort: String?
    let aboutFull: String?
    let longevityImpactShort: String?
    let longevityImpactFull: String?
    let optimalRanges: String?
    let commonMisconceptions: String?
    let relatedMarkers: [String]?
    let quickTips: [String]?

    init(from staticContent: EducationStaticContent) {
        self.aboutShort = staticContent.aboutContentShort
        self.longevityImpactShort = staticContent.longevityImpactShort
        self.relatedMarkers = staticContent.relatedMarkers

        // Extract full content from JSONB
        self.aboutFull = Self.extractText(from: staticContent.aboutContent)
        self.longevityImpactFull = Self.extractText(from: staticContent.longevityImpact)
        self.optimalRanges = Self.extractText(from: staticContent.optimalRangesExplanation)
        self.commonMisconceptions = Self.extractText(from: staticContent.commonMisconceptions)
        self.quickTips = Self.extractTips(from: staticContent.quickTips)
    }

    private static func extractText(from anyJson: AnyJSON?) -> String? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct string
        if case .string(let text) = anyJson {
            return text.isEmpty ? nil : text
        }

        // Case 2: Object with "text" or "content" key
        if case .object(let json) = anyJson {
            // Try "text" key first
            if case .string(let text) = json["text"] {
                return text.isEmpty ? nil : text
            }
            // Try "content" key (used by education_static_content)
            if case .string(let text) = json["content"] {
                return text.isEmpty ? nil : text
            }
            if case .array(let paragraphs) = json["paragraphs"] {
                let text = paragraphs.compactMap { paragraph -> String? in
                    if case .string(let text) = paragraph { return text }
                    return nil
                }.joined(separator: "\n\n")
                return text.isEmpty ? nil : text
            }
        }

        // Case 3: Array of strings
        if case .array(let items) = anyJson {
            let text = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }.joined(separator: "\n\n")
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private static func extractTips(from anyJson: AnyJSON?) -> [String]? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct array of strings
        if case .array(let items) = anyJson {
            let strings = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }
            return strings.isEmpty ? nil : strings
        }

        // Case 2: Object with "tips" array
        if case .object(let json) = anyJson {
            if case .array(let tips) = json["tips"] {
                let strings = tips.compactMap { tip -> String? in
                    if case .string(let text) = tip { return text }
                    return nil
                }
                return strings.isEmpty ? nil : strings
            }
        }

        return nil
    }
}

// MARK: - Backward Compatibility Aliases

/// Backward compatibility alias for existing biomarker views
typealias BiomarkerAboutModal = MetricEducationModal
typealias BiomarkerEducationContent = MetricEducationContent
typealias BiomarkerEducationContentLoader = MetricEducationContentLoader

// MARK: - Scoring Explanation Modal

/// Simple modal to display scoring explanation from display_views
struct ScoringExplanationModal: View {
    let viewId: String
    let title: String
    let color: Color
    @Binding var isPresented: Bool

    @State private var explanation: String?
    @State private var isLoading = true

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    } else if let explanation = explanation {
                        MarkdownTextView(markdown: explanation, color: color)
                    } else {
                        Text("Scoring explanation not available.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            await loadExplanation()
        }
    }

    private func loadExplanation() async {
        isLoading = true

        do {
            struct ViewRow: Decodable {
                let scoringExplanation: String?

                enum CodingKeys: String, CodingKey {
                    case scoringExplanation = "scoring_explanation"
                }
            }

            let results: [ViewRow] = try await supabase
                .from("display_views")
                .select("scoring_explanation")
                .eq("view_id", value: viewId)
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                self.explanation = results.first?.scoringExplanation
                self.isLoading = false
            }
        } catch {
            print("Error loading scoring explanation: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Markdown Text View

/// A view that renders markdown text with proper formatting
/// Handles ## headers, **bold**, and bullet points
struct MarkdownTextView: View {
    let markdown: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdown().enumerated()), id: \.offset) { _, element in
                switch element {
                case .header(let text):
                    Text(text)
                        .font(.headline)
                        .foregroundColor(color)
                        .padding(.top, 8)
                case .body(let text):
                    if let attrString = try? AttributedString(markdown: text) {
                        Text(attrString)
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(color)
                        if let attrString = try? AttributedString(markdown: text) {
                            Text(attrString)
                                .font(.body)
                                .foregroundColor(.primary)
                        } else {
                            Text(text)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum MarkdownElement {
        case header(String)
        case body(String)
        case bullet(String)
    }

    private func parseMarkdown() -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = markdown.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("## ") {
                let headerText = String(trimmed.dropFirst(3))
                elements.append(.header(headerText))
            } else if trimmed.hasPrefix("# ") {
                let headerText = String(trimmed.dropFirst(2))
                elements.append(.header(headerText))
            } else if trimmed.hasPrefix("- ") {
                let bulletText = String(trimmed.dropFirst(2))
                elements.append(.bullet(bulletText))
            } else if trimmed.hasPrefix("* ") {
                let bulletText = String(trimmed.dropFirst(2))
                elements.append(.bullet(bulletText))
            } else {
                elements.append(.body(trimmed))
            }
        }

        return elements
    }
}

// MARK: - Preview

#Preview {
    MetricEducationModal(
        viewId: "DISP_BIO_HDL",
        metricName: "HDL Cholesterol",
        color: .orange,
        isPresented: .constant(true)
    )
}
