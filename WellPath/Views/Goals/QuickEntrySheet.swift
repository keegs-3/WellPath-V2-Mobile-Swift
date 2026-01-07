//
//  QuickEntrySheet.swift
//  WellPath
//
//  Quick entry sheet for logging goal progress
//

import SwiftUI

struct QuickEntrySheet: View {
    let goal: PatientGoal
    let currentValue: Double
    let onSubmit: (Double) -> Void

    @State private var entryValue: Double = 0
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    private var quickEntryType: String {
        // Default to slider for most goals
        goal.template?.entryMethods?.primary ?? "slider"
    }

    private var config: QuickEntryConfig {
        // Create config based on goal properties
        QuickEntryConfig(
            min: 0,
            max: goal.targetValue * 2,  // Allow up to 2x target
            step: goal.targetValue >= 100 ? 10 : (goal.targetValue >= 10 ? 1 : 0.1),
            unit: goal.targetUnit,
            label: "Enter \(goal.title.lowercased())",
            values: nil
        )
    }

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Goal Info Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill((Color(hex: pillar.color) ?? .blue).opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: pillar.icon)
                            .font(.title)
                            .foregroundColor(Color(hex: pillar.color) ?? .blue)
                    }

                    Text(goal.title)
                        .font(.headline)

                    Text("Target: \(Int(goal.targetValue))\(goal.targetUnit)/\(goal.isWeekly ? "week" : "day")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if currentValue > 0 {
                        Text("Logged today: \(Int(currentValue))\(goal.targetUnit)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top)

                Divider()

                // Entry Input
                switch quickEntryType {
                case "checkbox":
                    CheckboxEntry(
                        label: config.label ?? "Did you complete this?",
                        value: $entryValue
                    )
                case "slider":
                    SliderEntry(
                        config: config,
                        unit: goal.targetUnit,
                        value: $entryValue
                    )
                default:
                    SliderEntry(
                        config: config,
                        unit: goal.targetUnit,
                        value: $entryValue
                    )
                }

                Spacer()

                // Submit Button
                Button {
                    isSubmitting = true
                    onSubmit(entryValue)
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Log Progress")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(entryValue > 0 ? Color(hex: pillar.color) : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(entryValue <= 0 || isSubmitting)

                // AI Tips
                if let tips = goal.aiTips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(tips.prefix(2), id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Checkbox Entry

struct CheckboxEntry: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                Button {
                    value = 1
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: value == 1 ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 44))
                            .foregroundColor(value == 1 ? .green : .gray)
                        Text("Yes")
                            .font(.subheadline)
                            .foregroundColor(value == 1 ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    value = 0
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: value == 0 ? "xmark.circle.fill" : "circle")
                            .font(.system(size: 44))
                            .foregroundColor(value == 0 ? .red : .gray)
                        Text("No")
                            .font(.subheadline)
                            .foregroundColor(value == 0 ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Stepper Entry (replaced slider with text field + stepper buttons)

struct SliderEntry: View {
    let config: QuickEntryConfig?
    let unit: String
    @Binding var value: Double

    @State private var textValue: String = ""

    private var minValue: Double { config?.min ?? 0 }
    private var maxValue: Double { config?.max ?? 200 }
    private var step: Double { config?.step ?? 10 }
    private var smallStep: Double { config?.step ?? 1 }
    private var largeStep: Double { (config?.step ?? 10) * 5 }
    private var label: String { config?.label ?? "Amount" }

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Stepper buttons with text field
            HStack(spacing: 16) {
                // Large decrease
                Button {
                    adjustValue(by: -largeStep)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
                .disabled(value <= minValue)

                // Small decrease
                Button {
                    adjustValue(by: -smallStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.7))
                }
                .disabled(value <= minValue)

                // Text field for direct input
                VStack(spacing: 4) {
                    TextField("0", text: $textValue)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                        .onChange(of: textValue) { _, newValue in
                            if let parsed = Double(newValue) {
                                value = min(max(parsed, minValue), maxValue)
                            }
                        }
                        .onAppear {
                            updateTextValue()
                        }

                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Small increase
                Button {
                    adjustValue(by: smallStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.7))
                }
                .disabled(value >= maxValue)

                // Large increase
                Button {
                    adjustValue(by: largeStep)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
                .disabled(value >= maxValue)
            }

            // Quick preset buttons
            HStack(spacing: 12) {
                ForEach(quickValues, id: \.self) { quickValue in
                    Button {
                        setValueTo(quickValue)
                    } label: {
                        Text("\(Int(quickValue))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Int(value) == Int(quickValue) ? Color.green : Color(uiColor: .tertiarySystemGroupedBackground))
                            .foregroundColor(Int(value) == Int(quickValue) ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }

    private func adjustValue(by delta: Double) {
        let newValue = min(max(value + delta, minValue), maxValue)
        setValueTo(newValue)
    }

    private func setValueTo(_ newValue: Double) {
        value = newValue
        updateTextValue()
    }

    private func updateTextValue() {
        textValue = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private var quickValues: [Double] {
        let range = maxValue - minValue
        return [
            minValue + range * 0.25,
            minValue + range * 0.5,
            minValue + range * 0.75,
            maxValue
        ]
    }
}

#Preview {
    QuickEntrySheet(
        goal: PatientGoal(
            goalId: "1",
            patientId: "1",
            recTypeId: "REC_PROTEIN_TOTAL",
            targetValue: 120,
            targetUnit: "g",
            targetFrequency: "daily",
            aiRationale: nil,
            aiTips: ["Aim for 30g at each meal", "Greek yogurt is a great snack"],
            trackingMode: "quick",
            status: .active,
            pauseReason: nil,
            cycleStart: "2025-01-01",
            cycleEnd: nil,
            assignedAt: "2025-01-01",
            sampleRecommendationTypes: RecommendationType(
                recTypeId: "REC_PROTEIN_TOTAL",
                title: "Daily Protein",
                description: "Hit your daily protein target",
                pillar: "Healthful Nutrition",
                category: "protein",
                trackingQuantityTypes: ["protein_grams"],
                targetUnit: "g",
                frequency: "daily",
                baselineTypes: nil,
                biomarkerTypes: nil,
                biometricTypes: nil,
                impactExplanation: nil,
                evidenceSummary: nil,
                targetCalculation: nil,
                entryMethods: nil,
                progressionTiers: nil,
                iconName: "fish.fill",
                colorHex: "#95E879",
                isActive: true
            )
        ),
        currentValue: 50,
        onSubmit: { _ in }
    )
}
