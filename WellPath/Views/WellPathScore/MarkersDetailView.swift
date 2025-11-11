//
//  MarkersDetailView.swift
//  WellPath
//
//  Detail view for Markers component (Biomarkers & Biometrics)
//

import SwiftUI
import Supabase

struct MarkersDetailView: View {
    let pillarName: String

    @State private var selectedView: MarkerView = .scoreHistory
    @State private var aboutContent: [PillarMarkersAbout] = []
    @State private var markers: [MarkerItem] = []
    @State private var isLoading = false
    @State private var isLoadingMarkers = false
    @State private var searchText = ""

    private var filteredMarkers: [MarkerItem] {
        if searchText.isEmpty {
            return markers
        }
        return markers.filter { marker in
            marker.itemDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    enum MarkerView: String, CaseIterable {
        case scoreHistory = "Score History"
        case breakdown = "Breakdown"
        case about = "About"
    }

    private let markersColor = Color(red: 0.40, green: 0.80, blue: 0.40)
    private let supabase = SupabaseManager.shared.client

    var body: some View {
        contentView
            .background(
                ZStack {
                    // Background gradient
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                markersColor.opacity(0.65),
                                markersColor.opacity(0.45),
                                markersColor.opacity(0.25),
                                markersColor.opacity(0.1),
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
                            Image(systemName: "chart.xyaxis.line")
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
            .navigationTitle("Markers")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadAboutContent()
                await loadMarkers()
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker
                Picker("View", selection: $selectedView) {
                    ForEach(MarkerView.allCases, id: \.self) { view in
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
            // Markers score trend chart
            ComponentScoreTrendChart(
                componentType: "markers",
                componentName: "Markers",
                componentColor: markersColor
            )
            .padding(.top, 8)

            // List of biomarkers and biometrics with weights
            VStack(alignment: .leading, spacing: 16) {
                Text("Biomarkers & Biometrics")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search markers", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                if isLoadingMarkers {
                    ProgressView("Loading markers...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if markers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No markers available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if filteredMarkers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredMarkers) { marker in
                            NavigationLink(destination: BiomarkerDetailView(
                                name: marker.name,
                                value: "", // BiomarkerDetailView fetches this
                                status: "", // BiomarkerDetailView fetches this
                                optimalRange: "", // BiomarkerDetailView fetches this
                                trend: "", // BiomarkerDetailView fetches this
                                isBiometric: marker.isBiometric
                            )) {
                                MarkerContainerRow(marker: marker)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Breakdown Content

    private var breakdownContent: some View {
        VStack(spacing: 24) {
            // Doughnut chart showing contribution of biomarkers/biometrics
            VStack(spacing: 16) {
                Text("Component Breakdown")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.top, 16)

                if markers.isEmpty {
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                } else {
                    MarkerBreakdownChart(markers: markers)
                        .padding(.horizontal)
                }
            }
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
                                    .foregroundColor(markersColor)
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
            let response: [PillarMarkersAbout] = try await supabase
                .from("wellpath_pillars_markers_about")
                .select()
                .eq("is_active", value: true)
                .eq("pillar_name", value: pillarName)
                .order("display_order", ascending: true)
                .execute()
                .value

            aboutContent = response
            print("📚 Loaded \(response.count) markers about content records for pillar '\(pillarName)'")
        } catch {
            print("❌ Error loading markers about content: \(error)")
        }
    }

    private func loadMarkers() async {
        isLoadingMarkers = true
        defer { isLoadingMarkers = false }

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            let response: [MarkerItem] = try await supabase
                .from("patient_item_scores_current_with_component_weights")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("pillar_name", value: pillarName)
                .eq("component_type", value: "markers")
                .order("item_weight_in_pillar", ascending: false)
                .execute()
                .value

            markers = response
            print("📊 Loaded \(response.count) markers for pillar '\(pillarName)'")
        } catch {
            print("❌ Error loading markers: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        MarkersDetailView(pillarName: "Healthful Nutrition")
    }
}
