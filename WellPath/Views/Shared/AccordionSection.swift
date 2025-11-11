//
//  AccordionSection.swift
//  WellPath
//
//  Reusable expandable accordion component for education content
//

import SwiftUI

struct AccordionSection: View {
    let title: String
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
    let color: Color

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .cornerRadius(isExpanded ? 12 : 12, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)

            // Content (shown when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // About content (general intro)
                    if let about = aboutContent, !about.isEmpty {
                        Text(.init(about))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    // Longevity impact section - with icon
                    if let impact = longevityImpact, !impact.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "heart.circle.fill")
                                .font(.title3)
                                .foregroundColor(color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Impact on your health")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundColor(.secondary)

                                Text(.init(impact))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Quick tips section - more compact
                    if let tips = quickTips, !tips.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.circle.fill")
                                .font(.title3)
                                .foregroundColor(color)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Quick Tips")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundColor(.secondary)

                                ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { index, tip in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .foregroundColor(color)
                                            .fontWeight(.bold)

                                        Text(tip)
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
        .padding(.horizontal)
    }
}

// Helper extension for selective corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    VStack(spacing: 20) {
        AccordionSection(
            title: "About Protein",
            aboutContent: "Protein is essential for building and repairing tissues, producing enzymes and hormones, and supporting immune function.",
            longevityImpact: "Higher protein intake, especially from plant sources and fish, is associated with better health outcomes and longevity.",
            quickTips: [
                "Aim for 20-40g protein per meal to maximize muscle protein synthesis",
                "Spread intake evenly across meals - don't load it all in one sitting",
                "Prioritize high-quality sources like fish, poultry, and legumes"
            ],
            color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
        )

        Spacer()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
