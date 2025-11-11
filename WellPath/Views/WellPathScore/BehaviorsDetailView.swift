//
//  BehaviorsDetailView.swift
//  WellPath
//
//  Detail view for Behaviors component (Lifestyle & Habits)
//

import SwiftUI
import Supabase

struct BehaviorsDetailView: View {
    let pillarName: String

    @State private var selectedView: BehaviorView = .scoreHistory
    @State private var aboutContent: [PillarBehaviorsAbout] = []
    @State private var isLoading = false

    enum BehaviorView: String, CaseIterable {
        case scoreHistory = "Score History"
        case breakdown = "Breakdown"
        case about = "About"
    }

    private let behaviorsColor = Color(red: 0.20, green: 0.60, blue: 0.86)
    private let supabase = SupabaseManager.shared.client

    var body: some View {
        contentView
            .background(
                ZStack {
                    // Background gradient
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                behaviorsColor.opacity(0.65),
                                behaviorsColor.opacity(0.45),
                                behaviorsColor.opacity(0.25),
                                behaviorsColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)
                        Spacer()
                    }

                    // Large background icon
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "figure.walk")
                                .font(.system(size: 200))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .rotationEffect(.degrees(-15))
                                .offset(x: 50, y: -50)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Behaviors")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadAboutContent()
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker
                Picker("View", selection: $selectedView) {
                    ForEach(BehaviorView.allCases, id: \.self) { view in
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
    }

    // MARK: - Score History Content

    private var scoreHistoryContent: some View {
        VStack(spacing: 16) {
            // Behaviors score trend chart
            ComponentScoreTrendChart(
                componentType: "behaviors",
                componentName: "Behaviors",
                componentColor: behaviorsColor
            )
            .padding(.top, 8)

            // List of behaviors with weights
            VStack(alignment: .leading, spacing: 16) {
                Text("Tracked Behaviors")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal)

                Text("Lifestyle behaviors and habits that contribute to your Behaviors score will be listed here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Breakdown Content

    private var breakdownContent: some View {
        VStack(spacing: 24) {
            // Doughnut chart showing contribution of behaviors
            VStack(spacing: 16) {
                Text("Component Breakdown")
                    .font(.system(size: 20, weight: .semibold))

                Text("Doughnut chart showing % contribution of tracked behaviors will be displayed here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - About Content

    private var aboutContentView: some View {
        VStack(spacing: 24) {
            if isLoading {
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
                                    .foregroundColor(behaviorsColor)
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

    // MARK: - Data Loading

    private func loadAboutContent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PillarBehaviorsAbout] = try await supabase
                .from("wellpath_pillars_behaviors_about")
                .select()
                .eq("is_active", value: true)
                .eq("pillar_name", value: pillarName)
                .order("display_order", ascending: true)
                .execute()
                .value

            aboutContent = response
            print("📚 Loaded \(response.count) behaviors about content records for pillar '\(pillarName)'")
        } catch {
            print("❌ Error loading behaviors about content: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        BehaviorsDetailView(pillarName: "Healthful Nutrition")
    }
}
