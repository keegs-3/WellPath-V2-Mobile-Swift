//
//  EducationAccordionSection.swift
//  WellPath
//
//  Expandable accordion component for biomarker/biometric education sections
//

import SwiftUI

struct EducationAccordionSection: View {
    let sectionNumber: Int
    let title: String
    let content: String
    let color: Color

    @State private var isExpanded = false

    // Fun SF icons that rotate based on section number
    var sectionIcon: String {
        let icons = ["lightbulb.fill", "book.fill", "brain.head.profile", "sparkles", "star.fill", "heart.fill", "leaf.fill"]
        return icons[(sectionNumber - 1) % icons.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Section icon
                    Image(systemName: sectionIcon)
                        .font(.title3)
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }

            // Content (shown when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(.init(content))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .padding(.top, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 12) {
        EducationAccordionSection(
            sectionNumber: 1,
            title: "What is Apolipoprotein B?",
            content: "Apolipoprotein B (ApoB) is a protein found on the surface of lipoproteins that carry cholesterol and triglycerides through your bloodstream. Unlike traditional cholesterol tests that measure the amount of cholesterol, ApoB counts the number of cholesterol-carrying particles in your blood.",
            color: Color(red: 0.74, green: 0.56, blue: 0.94)
        )

        EducationAccordionSection(
            sectionNumber: 2,
            title: "Why it Matters",
            content: "ApoB is considered one of the most accurate predictors of cardiovascular disease risk. Each ApoB particle can penetrate and become trapped in artery walls, leading to plaque buildup and atherosclerosis.",
            color: Color(red: 0.74, green: 0.56, blue: 0.94)
        )

        Spacer()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
