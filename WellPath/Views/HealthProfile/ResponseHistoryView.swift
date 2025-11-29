//
//  ResponseHistoryView.swift
//  WellPath
//
//  Timeline view showing the history of changes to a survey response.
//  Displays audit trail entries with change type, source, and timestamps.
//

import SwiftUI

struct ResponseHistoryView: View {
    let history: [SurveyResponseHistory]
    let questionText: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    emptyView
                } else {
                    historyList
                }
            }
            .navigationTitle("Response History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Question context header
                if let question = questionText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Question")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(question)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                // Timeline entries
                VStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                        HistoryEntryRow(
                            entry: entry,
                            isFirst: index == 0,
                            isLast: index == history.count - 1
                        )
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Changes to this response will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: SurveyResponseHistory
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Top line
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 16)

                // Icon
                Image(systemName: entry.iconName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(iconColor)
                    .cornerRadius(12)

                // Bottom line
                Rectangle()
                    .fill(isLast ? Color.clear : Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    Text(entry.changeTypeDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("by \(entry.changeSourceDisplay)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(entry.changedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Previous value (for updates/deletes)
                if let previous = entry.previousResponseText, !previous.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                        Text(previous)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                }

                // Current value (for creates/updates)
                if entry.changeType != "deleted" && entry.changeType != "cascade_deleted",
                   let current = entry.responseText, !current.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.7))
                        Text(current)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }

                // Source metric info (for tracked data updates)
                if entry.changeSource == "tracked_data", let metric = entry.sourceMetricId {
                    Label("Updated from \(metric)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }

                // Cascade source info
                if entry.changeType == "cascade_deleted", let source = entry.sourceQuestionNumber {
                    Label("Triggered by Q\(source) change", systemImage: "link")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal)
    }

    private var iconColor: Color {
        switch entry.changeType {
        case "created": return .green
        case "updated": return .blue
        case "deleted": return .red
        case "cascade_deleted": return .orange
        default: return .gray
        }
    }
}

// MARK: - Sheet Presentation Modifier

struct ResponseHistorySheet: ViewModifier {
    @Binding var isPresented: Bool
    let history: [SurveyResponseHistory]
    let questionText: String?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ResponseHistoryView(history: history, questionText: questionText)
            }
    }
}

extension View {
    func responseHistorySheet(
        isPresented: Binding<Bool>,
        history: [SurveyResponseHistory],
        questionText: String? = nil
    ) -> some View {
        modifier(ResponseHistorySheet(isPresented: isPresented, history: history, questionText: questionText))
    }
}

// MARK: - History Button (for question headers)

struct ResponseHistoryButton: View {
    let historyCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                if historyCount > 1 {
                    Text("\(historyCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Empty") {
    ResponseHistoryView(history: [], questionText: "How would you describe your typical eating pattern?")
}

#Preview("History Button") {
    HStack {
        ResponseHistoryButton(historyCount: 3) {
            print("Show history")
        }
        ResponseHistoryButton(historyCount: 1) {
            print("Show history")
        }
    }
    .padding()
}
