//
//  OverallAdherenceRing.swift
//  WellPath
//
//  Hero widget showing overall weekly adherence across all active goals
//  Semi-circular arc design with landscape wave background
//

import SwiftUI

struct OverallAdherenceRing: View {
    let weeklyProgress: Double  // 0-100
    let maxPotential: Double    // 0-100
    let goalCount: Int

    @State private var animatedProgress: Double = 0
    @State private var animatedMax: Double = 0

    // WellPath green theme
    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    private var statusMessage: String {
        if weeklyProgress >= 90 {
            return "Outstanding!"
        } else if weeklyProgress >= 75 {
            return "Great Progress"
        } else if weeklyProgress >= 50 {
            return "Keep Going"
        } else if weeklyProgress >= 25 {
            return "Building Momentum"
        } else {
            return "Get Started"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero section with background imagery
            ZStack {
                // Background gradient with waves - creates "horizon" effect
                AdherenceHeroBackground(accentColor: wellPathGreen)

                // Arc and content overlay
                VStack(spacing: 4) {
                    // Arc gauge - LARGER frame for visibility
                    AdherenceArcGauge(
                        progress: animatedProgress,
                        maxPotential: animatedMax
                    )
                    .frame(height: 85)
                    .padding(.top, 20)

                    // Large score
                    Text("\(Int(animatedProgress))")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .foregroundColor(.white)

                    // Label
                    Text("WEEKLY ADHERENCE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)

                    // Max potential (still achievable) - in green
                    Text("\(Int(animatedMax))% still achievable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(wellPathGreen)
                        .padding(.top, 4)

                    // View goals link
                    HStack(spacing: 4) {
                        Text("View goals")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = weeklyProgress
                animatedMax = maxPotential
            }
        }
        .onChange(of: weeklyProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: maxPotential) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedMax = newValue
            }
        }
    }
}

// MARK: - Hero Background with Image or Waves

struct AdherenceHeroBackground: View {
    let accentColor: Color

    // Set this to true to use an image from the asset catalog
    // Add an image named "goals_hero_background" to Assets.xcassets
    private let useImageBackground = true
    private let imageName = "goals_hero_background"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Try to use image background first
                if useImageBackground, let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()

                    // Dark overlay for text readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    // Fallback: Programmatic gradient with waves
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.18),
                            Color(red: 0.12, green: 0.18, blue: 0.24),
                            accentColor.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Layered wave shapes creating horizon effect
                    WaveLayerStack(
                        size: geometry.size,
                        accentColor: accentColor
                    )

                    // Topographic pattern overlay for texture
                    TopographicPattern(
                        color: .white,
                        opacity: 0.06,
                        lineSpacing: 16,
                        fadeStart: 0.0,
                        fadeEnd: 0.7
                    )
                }
            }
        }
    }
}

// MARK: - Layered Wave Stack

struct WaveLayerStack: View {
    let size: CGSize
    let accentColor: Color

    var body: some View {
        ZStack {
            // Back wave layer - subtle
            WaveShape(amplitude: 12, frequency: 1.5, phase: 0.3)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.1), accentColor.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: size.height * 0.55)

            // Middle wave layer
            WaveShape(amplitude: 15, frequency: 1.2, phase: 0)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.15), accentColor.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: size.height * 0.65)

            // Front wave layer - most prominent
            WaveShape(amplitude: 10, frequency: 0.8, phase: 0.5)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.25), accentColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: size.height * 0.75)
        }
    }
}

// MARK: - Wave Shape

struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let midY = height * 0.3

        path.move(to: CGPoint(x: 0, y: midY))

        // Create smooth wave curve
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * 2 * .pi) + (phase * 2 * .pi))
            let y = midY + (sine * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Complete the shape by going to bottom corners
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Adherence Arc Gauge (Works on any background)

struct AdherenceArcGauge: View {
    let progress: Double      // 0-100
    let maxPotential: Double  // 0-100

    private let accentColor = Color(red: 0.56, green: 0.82, blue: 0.31)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Arc layout - more curved
            let sidePadding: CGFloat = 40
            let arcTopY: CGFloat = 8             // Top of arc curve (lower = more curve)
            let arcBottomY: CGFloat = height - 12  // Bottom endpoints of arc (room for indicator glow)
            let labelOffset: CGFloat = -12       // How far above arc to place labels/dots

            let arcStartX = sidePadding
            let arcEndX = width - sidePadding

            Canvas { context, _ in

                // Helper: get point on arc at a given percent (0-100)
                func pointOnArc(percent: Double) -> CGPoint {
                    let t = percent / 100.0
                    let x = arcStartX + (arcEndX - arcStartX) * t
                    // Quadratic bezier: y = (1-t)²*p0 + 2(1-t)t*control + t²*p1
                    let y = pow(1-t, 2) * arcBottomY + 2 * (1-t) * t * arcTopY + pow(t, 2) * arcBottomY
                    return CGPoint(x: x, y: y)
                }

                // Helper: create arc path from 0 to a given percent
                func arcPath(toPercent: Double) -> Path {
                    var path = Path()
                    path.move(to: pointOnArc(percent: 0))
                    let steps = max(Int(toPercent), 1)
                    for i in 1...steps {
                        path.addLine(to: pointOnArc(percent: Double(i)))
                    }
                    return path
                }

                // === LAYER 1: Background arc (0-100, white, transparent) ===
                context.stroke(
                    arcPath(toPercent: 100),
                    with: .color(.white.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

                // === LAYER 2: Max potential arc (green, transparent) ===
                if maxPotential > 0 {
                    context.stroke(
                        arcPath(toPercent: maxPotential),
                        with: .color(accentColor.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                }

                // === LAYER 3: Current progress arc (green, solid) ===
                if progress > 0 {
                    context.stroke(
                        arcPath(toPercent: progress),
                        with: .color(accentColor),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                }

                // === LABELS/DOTS following the arc curve (further above) ===
                let dotOffset: CGFloat = -20  // Further above arc

                // "0" label at 0% position
                let pos0 = pointOnArc(percent: 0)
                context.draw(
                    Text("0").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                    at: CGPoint(x: pos0.x, y: pos0.y + dotOffset)
                )

                // "100" label at 100% position
                let pos100 = pointOnArc(percent: 100)
                context.draw(
                    Text("100").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                    at: CGPoint(x: pos100.x, y: pos100.y + dotOffset)
                )

                // Dots at 20, 40, 60, 80 (following the arc curve)
                for percent in [20, 40, 60, 80] {
                    let pos = pointOnArc(percent: Double(percent))
                    context.fill(
                        Path(ellipseIn: CGRect(x: pos.x - 2, y: pos.y + dotOffset - 2, width: 4, height: 4)),
                        with: .color(.white.opacity(0.4))
                    )
                }

                // === Current progress indicator (solid dot) ===
                let indicatorPos = pointOnArc(percent: progress)

                // Glow
                context.fill(
                    Path(ellipseIn: CGRect(x: indicatorPos.x - 10, y: indicatorPos.y - 10, width: 20, height: 20)),
                    with: .color(accentColor.opacity(0.4))
                )
                // Main dot
                context.fill(
                    Path(ellipseIn: CGRect(x: indicatorPos.x - 6, y: indicatorPos.y - 6, width: 12, height: 12)),
                    with: .color(accentColor)
                )
            }
        }
    }
}

// MARK: - Semi Circle Arc Shape

struct SemiCircleArc: Shape {
    var progress: Double // 0.0 to 1.0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2

        // Semi-circle from 180° to 0° (left to right across the top)
        let startAngle = Angle(degrees: 180)
        let endAngle = Angle(degrees: 180 - (180 * progress))

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        return path
    }
}

// MARK: - Compact Version (for smaller spaces)

struct CompactAdherenceRing: View {
    let weeklyProgress: Double
    let goalCount: Int

    private var progressColor: Color {
        if weeklyProgress >= 80 {
            return Color.green
        } else if weeklyProgress >= 50 {
            return Color.yellow
        } else {
            return Color.orange
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: min(weeklyProgress / 100, 1.0))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(weeklyProgress))%")
                    .font(.caption2)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Adherence")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(goalCount) active goals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Empty State (No Goals Yet)

struct EmptyAdherenceRing: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                SemiCircleArc(progress: 1.0)
                    .stroke(
                        Color.gray.opacity(0.2),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 200, height: 100)

                VStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No Goals Yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .offset(y: -10)
            }
            .frame(height: 140)

            Text("Your personalized goals will appear here once your clinician reviews your health data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}

// MARK: - Onboarding Stage Enum

enum OnboardingStage: CaseIterable {
    case loading
    case baseline
    case labs
    case biometrics
    case clinicianReview

    var title: String {
        switch self {
        case .loading: return "Loading..."
        case .baseline: return "Health Profile"
        case .labs: return "Lab Results"
        case .biometrics: return "Biometrics"
        case .clinicianReview: return "Clinician Review"
        }
    }

    var subtitle: String {
        switch self {
        case .loading: return ""
        case .baseline: return "Complete your baseline assessments"
        case .labs: return "Awaiting your lab results"
        case .biometrics: return "Schedule your biometric screening"
        case .clinicianReview: return "Your clinician is preparing your goals"
        }
    }

    var icon: String {
        switch self {
        case .loading: return "arrow.2.circlepath"
        case .baseline: return "list.clipboard.fill"
        case .labs: return "testtube.2"
        case .biometrics: return "heart.text.clipboard.fill"
        case .clinicianReview: return "person.badge.clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .loading: return .gray
        case .baseline: return .blue
        case .labs: return .purple
        case .biometrics: return .red
        case .clinicianReview: return .orange
        }
    }

    var stageNumber: Int {
        switch self {
        case .loading: return 0
        case .baseline: return 1
        case .labs: return 2
        case .biometrics: return 3
        case .clinicianReview: return 4
        }
    }

    static let totalStages = 4
}

// MARK: - Onboarding Adherence Ring (Journey Progress)

struct OnboardingAdherenceRing: View {
    let stage: OnboardingStage
    let stageProgress: Double  // 0-1 progress within current stage
    var onTap: (() -> Void)?

    @State private var animatedProgress: Double = 0

    private let ringSize: CGFloat = 200
    private let lineWidth: CGFloat = 16

    // Overall progress: completed stages + current stage progress
    private var overallProgress: Double {
        let completedStages = Double(stage.stageNumber - 1)
        let currentStageContribution = stageProgress
        let total = (completedStages + currentStageContribution) / Double(OnboardingStage.totalStages)
        return min(max(total, 0), 1)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background arc (gray)
                SemiCircleArc(progress: 1.0)
                    .stroke(
                        Color.gray.opacity(0.2),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize / 2)

                // Progress arc (colored based on stage)
                SemiCircleArc(progress: animatedProgress)
                    .stroke(
                        stage.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize / 2)

                // Center content
                VStack(spacing: 8) {
                    Image(systemName: stage.icon)
                        .font(.system(size: 36))
                        .foregroundColor(stage.color)

                    Text(stage.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .offset(y: -10)
            }
            .frame(height: ringSize / 2 + 40)

            // Stage indicators
            HStack(spacing: 12) {
                ForEach(1...OnboardingStage.totalStages, id: \.self) { stageNum in
                    StageIndicator(
                        stageNumber: stageNum,
                        isCompleted: stageNum < stage.stageNumber,
                        isCurrent: stageNum == stage.stageNumber,
                        color: stage.color
                    )
                }
            }

            // Description
            Text(stage.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // CTA if tappable
            if onTap != nil {
                Button {
                    onTap?()
                } label: {
                    HStack(spacing: 4) {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(stage.color)
                    .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = overallProgress
            }
        }
        .onChange(of: stageProgress) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = overallProgress
            }
        }
    }
}

// MARK: - Stage Indicator Dot

struct StageIndicator: View {
    let stageNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? color : (isCurrent ? color.opacity(0.3) : Color.gray.opacity(0.2)))
                .frame(width: 32, height: 32)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else {
                Text("\(stageNumber)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrent ? color : .secondary)
            }
        }
    }
}

// MARK: - Coming Soon Challenges Card (for onboarding)

struct ComingSoonChallengesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)

                Text("Challenges")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()
            }

            // Example challenge card (styled like a real one)
            HStack(spacing: 12) {
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: 0.33)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("1/3")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("10K Steps Challenge")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Hit 10,000 steps for 3 days straight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
            .opacity(0.6)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Tutorial Adherence Ring (During Onboarding)

struct TutorialAdherenceRing: View {
    let journeyState: PatientJourneyState

    // WellPath green theme
    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    private var stageMessage: String {
        switch journeyState {
        case .baselineCollection:
            return "Complete setup to unlock your personalized goals"
        case .awaitingLabs:
            return "Waiting for lab results..."
        case .awaitingBiometrics:
            return "Biometric screening needed"
        case .awaitingClinicianReview:
            return "Your clinician is preparing your goals"
        default:
            return "Your goals will appear here"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero section with background imagery
            ZStack {
                // Background gradient with waves - dimmed for tutorial
                AdherenceHeroBackground(accentColor: wellPathGreen)
                    .opacity(0.6)

                // Arc and content overlay
                VStack(spacing: 8) {
                    // Arc gauge with placeholder data
                    AdherenceArcGauge(
                        progress: 0,
                        maxPotential: 0
                    )
                    .frame(height: 70)
                    .padding(.top, 16)
                    .opacity(0.4)

                    // Placeholder score
                    Text("--")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    // Label
                    Text("WEEKLY ADHERENCE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Content section below hero
            VStack(spacing: 12) {
                // Coming Soon badge
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Coming Soon")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
                .padding(.top, 16)

                // Stage message
                Text(stageMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Tutorial Ring") {
    TutorialAdherenceRing(journeyState: .baselineCollection(completed: 2, total: 7))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Full Ring") {
    VStack(spacing: 20) {
        OverallAdherenceRing(
            weeklyProgress: 78,
            maxPotential: 92,
            goalCount: 5
        )

        OverallAdherenceRing(
            weeklyProgress: 45,
            maxPotential: 100,
            goalCount: 3
        )
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Compact") {
    VStack(spacing: 12) {
        CompactAdherenceRing(weeklyProgress: 78, goalCount: 5)
        CompactAdherenceRing(weeklyProgress: 45, goalCount: 3)
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Empty State") {
    EmptyAdherenceRing()
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Onboarding - Baseline") {
    OnboardingAdherenceRing(
        stage: .baseline,
        stageProgress: 0.3,
        onTap: { print("Tapped!") }
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Onboarding - Labs") {
    OnboardingAdherenceRing(
        stage: .labs,
        stageProgress: 0,
        onTap: nil
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Onboarding - Clinician Review") {
    OnboardingAdherenceRing(
        stage: .clinicianReview,
        stageProgress: 0,
        onTap: nil
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Coming Soon Challenges") {
    ComingSoonChallengesCard()
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
