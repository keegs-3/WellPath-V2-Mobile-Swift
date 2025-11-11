//
//  EducationDetailView.swift
//  WellPath
//
//  Detail view for Education component
//

import SwiftUI
import Supabase

struct EducationDetailView: View {
    let pillarName: String

    @State private var educationItems: [EducationScore] = []
    @State private var isLoading = false
    @State private var selectedView: EducationView = .scoreHistory
    @State private var aboutContent: [PillarEducationAbout] = []
    @State private var isLoadingAbout = false

    private let supabase = SupabaseManager.shared.client
    private let educationColor = Color(red: 0.74, green: 0.56, blue: 0.94)

    enum EducationView: String, CaseIterable {
        case scoreHistory = "Score History"
        case breakdown = "Breakdown"
        case about = "About"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker
                Picker("View", selection: $selectedView) {
                    ForEach(EducationView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Content based on selected view
                switch selectedView {
                case .scoreHistory:
                    scoreHistoryContent
                case .breakdown:
                    breakdownContent
                case .about:
                    aboutContentView
                }
            }
        }
        .navigationTitle("Education")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
            await loadAboutContent()
        }
    }

    private var scoreHistoryContent: some View {
        VStack(spacing: 24) {
            ComponentScoreTrendChart(
                componentType: "education",
                componentName: "Education",
                componentColor: Color(red: 0.74, green: 0.56, blue: 0.94)
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private var breakdownContent: some View {
        VStack(spacing: 24) {
            if isLoading {
                ProgressView()
                    .padding()
            } else if !educationItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Learning Content")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    ForEach(educationItems) { item in
                        EducationRow(item: item)
                    }
                }
            }
        }
        .padding(.vertical)
    }

    private var aboutContentView: some View {
        VStack(spacing: 24) {
            if isLoadingAbout {
                ProgressView()
                    .padding()
            } else if aboutContent.isEmpty {
                Text("No content available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(aboutContent.sorted(by: { $0.displayOrder < $1.displayOrder })) { content in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(educationColor)
                                    .font(.title3)
                                Text(content.sectionTitle)
                                    .font(.headline)
                            }

                            Text(.init(content.sectionContent))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            // Load education items across all pillars
            let response: [EducationScore] = try await supabase
                .from("patient_education_scores_by_pillar")
                .select("""
                    education_item_id,
                    education_item_title,
                    completion_status,
                    completion_percentage,
                    points_earned,
                    max_points,
                    weight_in_pillar,
                    completed_date
                """)
                .eq("patient_id", value: userId.uuidString)
                .order("weight_in_pillar", ascending: false)
                .execute()
                .value

            educationItems = response

        } catch {
            print("❌ Error loading education: \(error)")
        }
    }

    func loadAboutContent() async {
        isLoadingAbout = true
        defer { isLoadingAbout = false }

        do {
            let response: [PillarEducationAbout] = try await supabase
                .from("wellpath_pillars_education_about")
                .select("*, pillars_base!inner(pillar_name)")
                .eq("is_active", value: true)
                .eq("pillars_base.pillar_name", value: pillarName)
                .order("display_order", ascending: true)
                .execute()
                .value

            aboutContent = response
            print("📚 Loaded \(response.count) education about content records for pillar '\(pillarName)'")
        } catch {
            print("❌ Error loading education about content: \(error)")
        }
    }
}

struct EducationRow: View {
    let item: EducationScore

    var body: some View {
        Button(action: {
            // TODO: Navigate to education content
            print("Navigate to education item: \(item.educationItemId)")
        }) {
            HStack(spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.educationItemTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        // Completion badge
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(statusColor)
                            Text(statusLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("•")
                            .foregroundColor(.secondary)

                        // Points
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("\(Int(item.pointsEarned))/\(Int(item.maxPoints)) pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Progress bar if in progress
                    if item.completionStatus == "in_progress",
                       let progress = item.completionPercentage {
                        ProgressView(value: progress / 100.0)
                            .tint(Color(red: 0.74, green: 0.56, blue: 0.94))
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var statusColor: Color {
        switch item.completionStatus {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        case "started":
            return .orange
        default:
            return .gray
        }
    }

    var statusIcon: String {
        switch item.completionStatus {
        case "completed":
            return "checkmark.circle.fill"
        case "in_progress":
            return "clock.fill"
        case "started":
            return "play.circle.fill"
        default:
            return "circle"
        }
    }

    var statusLabel: String {
        switch item.completionStatus {
        case "completed":
            if let date = item.completedDate {
                return "Completed \(formatDate(date))"
            }
            return "Completed"
        case "in_progress":
            if let progress = item.completionPercentage {
                return "\(Int(progress))% complete"
            }
            return "In Progress"
        case "started":
            return "Started"
        default:
            return "Not Started"
        }
    }

    func formatDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoDate) else {
            return ""
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        EducationDetailView(pillarName: "Healthful Nutrition")
    }
}
