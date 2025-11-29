//
//  CascadeWarningAlert.swift
//  WellPath
//
//  Alert and confirmation views for cascade delete warnings.
//  Shown when changing a source question that will invalidate dependent question answers.
//

import SwiftUI

// MARK: - Cascade Warning Alert (ViewModifier)

struct CascadeWarningAlert: ViewModifier {
    @Binding var isPresented: Bool
    let affectedQuestions: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("This will reset related answers", isPresented: $isPresented) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Button("Continue", role: .destructive) {
                    onConfirm()
                }
            } message: {
                Text(alertMessage)
            }
    }

    private var alertMessage: String {
        if affectedQuestions.count == 1 {
            return "Changing this answer will clear your response to 1 related question. You'll need to answer it again."
        } else {
            return "Changing this answer will clear your responses to \(affectedQuestions.count) related questions. You'll need to answer them again."
        }
    }
}

extension View {
    func cascadeWarningAlert(
        isPresented: Binding<Bool>,
        affectedQuestions: [String],
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(CascadeWarningAlert(
            isPresented: isPresented,
            affectedQuestions: affectedQuestions,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}

// MARK: - Cascade Warning Banner (Inline)

struct CascadeWarningBanner: View {
    let affectedCount: Int
    var onLearnMore: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Linked Question")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Text("Changing this will reset \(affectedCount) related answer\(affectedCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onLearnMore = onLearnMore {
                Button {
                    onLearnMore()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Cascade Info Sheet

struct CascadeInfoSheet: View {
    let sourceQuestion: String
    let dependentQuestions: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Explanation
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Linked Questions")
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Text("Some questions in your Health Profile depend on your answers to previous questions. When you change your answer to a source question, related questions need to be answered again because their options may have changed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Example visualization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            // Source question
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(Text("1").font(.caption2).fontWeight(.bold).foregroundColor(.white))

                                VStack(alignment: .leading) {
                                    Text("Source Question")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("\"Which areas would you like to focus on?\"")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                            // Arrow
                            Image(systemName: "arrow.down")
                                .foregroundColor(.secondary)

                            // Dependent question
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 24, height: 24)
                                    .overlay(Text("2").font(.caption2).fontWeight(.bold).foregroundColor(.white))

                                VStack(alignment: .leading) {
                                    Text("Dependent Question")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("\"Rank your selected focus areas\" (uses your selections)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // Current situation
                    if !dependentQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Questions That Will Reset")
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(dependentQuestions, id: \.self) { question in
                                    HStack {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("Q\(question)")
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }

                    // Why this matters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why We Do This")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("This ensures your Health Profile stays consistent. If the options for a dependent question came from your previous answer, changing that answer means the dependent options are no longer valid. We clear them so you can provide accurate responses with the new options.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About Linked Questions")
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
}

// MARK: - Cascade Confirmation Sheet (Full Screen Alternative)

struct CascadeConfirmationSheet: View {
    let affectedQuestions: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Warning icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(20)

                // Title
                Text("Reset Related Answers?")
                    .font(.title2)
                    .fontWeight(.bold)

                // Message
                VStack(spacing: 8) {
                    Text("Changing this answer will clear")
                        .foregroundColor(.secondary)

                    Text("\(affectedQuestions.count) related answer\(affectedQuestions.count == 1 ? "" : "s")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("You'll need to answer them again.")
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text("Continue Anyway")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }

                    Button {
                        onCancel()
                        dismiss()
                    } label: {
                        Text("Keep My Answer")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Alert Modifier") {
    struct PreviewView: View {
        @State private var showAlert = true

        var body: some View {
            Button("Show Alert") {
                showAlert = true
            }
            .cascadeWarningAlert(
                isPresented: $showAlert,
                affectedQuestions: ["1.02", "1.03"],
                onConfirm: { print("Confirmed") }
            )
        }
    }
    return PreviewView()
}

#Preview("Banner") {
    VStack {
        CascadeWarningBanner(affectedCount: 2) {
            print("Learn more")
        }
        CascadeWarningBanner(affectedCount: 1)
    }
    .padding()
}

#Preview("Info Sheet") {
    CascadeInfoSheet(
        sourceQuestion: "1.01",
        dependentQuestions: ["1.02", "1.03"]
    )
}

#Preview("Confirmation Sheet") {
    CascadeConfirmationSheet(
        affectedQuestions: ["1.02", "1.03"],
        onConfirm: { print("Confirmed") },
        onCancel: { print("Cancelled") }
    )
}
