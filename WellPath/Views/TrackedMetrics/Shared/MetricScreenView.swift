//
//  MetricScreenView.swift
//  WellPath
//
//  Container view for card-based metric screens
//  Displays primary card followed by indented sub-cards
//

import SwiftUI

struct MetricScreenView<PrimaryContent: View, SubCards: View>: View {
    let title: String
    let color: Color
    let screenIcon: String
    let primaryContent: PrimaryContent
    let subCards: SubCards

    // Optional callbacks for toolbar actions
    var onDataManagement: (() -> Void)?
    var onAddEntry: (() -> Void)?

    init(
        title: String,
        color: Color,
        screenIcon: String,
        @ViewBuilder primaryContent: () -> PrimaryContent,
        @ViewBuilder subCards: () -> SubCards
    ) {
        self.title = title
        self.color = color
        self.screenIcon = screenIcon
        self.primaryContent = primaryContent()
        self.subCards = subCards()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Primary card (full width)
                primaryContent

                // Sub-cards (indented)
                VStack(spacing: 12) {
                    subCards
                }
                .padding(.leading, 16)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let onDataManagement = onDataManagement {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDataManagement()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }

            if let onAddEntry = onAddEntry {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAddEntry()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    // Fluent API for setting callbacks
    func onDataManagement(_ action: @escaping () -> Void) -> MetricScreenView {
        var copy = self
        copy.onDataManagement = action
        return copy
    }

    func onAddEntry(_ action: @escaping () -> Void) -> MetricScreenView {
        var copy = self
        copy.onAddEntry = action
        return copy
    }
}

#Preview {
    NavigationStack {
        MetricScreenView(
            title: "Protein",
            color: .green,
            screenIcon: "fork.knife"
        ) {
            // Primary content
            VStack(alignment: .leading, spacing: 8) {
                Text("Protein Amount")
                    .font(.headline)
                Text("Primary chart goes here")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        } subCards: {
            // Sub-cards
            ForEach(["Timing", "Type", "Ratio"], id: \.self) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Protein \(item)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Mini chart")
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
}
