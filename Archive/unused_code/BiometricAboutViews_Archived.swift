//
//  BiometricAboutViews_Archived.swift
//  WellPath
//
//  ARCHIVED: 2025-12-10
//  REASON: Replaced by MetricEducationModal which has expand + chat features
//  These views used BiometricEducationLoader which loads from a different source
//  than MetricEducationModal (which loads from education_static_content)
//

import SwiftUI

// MARK: - About View (ARCHIVED)

struct BiometricAboutView: View {
    @ObservedObject var educationLoader: BiometricEducationLoader
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if educationLoader.isLoading {
                        ProgressView("Loading education content...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if educationLoader.sections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No education content available")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(educationLoader.sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: iconForSection(section.sectionTitle))
                                        .foregroundColor(color)
                                    Text(section.sectionTitle)
                                        .font(.headline)
                                }
                                Text(section.sectionContent)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Back to chart button
            Button(action: onDismiss) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func iconForSection(_ title: String) -> String {
        let titleLower = title.lowercased()
        if titleLower.contains("overview") || titleLower.contains("about") {
            return "info.circle.fill"
        } else if titleLower.contains("longevity") || titleLower.contains("health") || titleLower.contains("impact") {
            return "heart.circle.fill"
        } else if titleLower.contains("range") || titleLower.contains("optimal") {
            return "chart.bar.fill"
        } else if titleLower.contains("tip") || titleLower.contains("improve") {
            return "lightbulb.circle.fill"
        }
        return "doc.text.fill"
    }
}

// MARK: - About Modal (Sheet) (ARCHIVED)

/// Modal sheet version of the About view for cleaner presentation
struct BiometricAboutModal: View {
    let title: String
    @ObservedObject var educationLoader: BiometricEducationLoader
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if educationLoader.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading education content...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if educationLoader.sections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No education content available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Check back soon for information about this metric.")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(educationLoader.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: iconForSection(section.sectionTitle))
                                        .font(.title3)
                                        .foregroundColor(color)
                                    Text(section.sectionTitle)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }

                                Text(section.sectionContent)
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
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("About \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func iconForSection(_ title: String) -> String {
        let titleLower = title.lowercased()
        if titleLower.contains("overview") || titleLower.contains("about") {
            return "info.circle.fill"
        } else if titleLower.contains("longevity") || titleLower.contains("health") || titleLower.contains("impact") {
            return "heart.circle.fill"
        } else if titleLower.contains("range") || titleLower.contains("optimal") {
            return "chart.bar.fill"
        } else if titleLower.contains("tip") || titleLower.contains("improve") {
            return "lightbulb.circle.fill"
        } else if titleLower.contains("status") || titleLower.contains("your") {
            return "person.circle.fill"
        } else if titleLower.contains("trend") {
            return "chart.line.uptrend.xyaxis"
        } else if titleLower.contains("step") || titleLower.contains("next") {
            return "arrow.right.circle.fill"
        }
        return "doc.text.fill"
    }
}
