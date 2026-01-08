//
//  TherapeuticDosingCard.swift
//  WellPath
//
//  Styled dosing card with ± buttons, DB-driven unit picker, and frequency stepper.
//  Uses substance-specific units from therapeutic_unit_options table.
//

import SwiftUI

struct TherapeuticDosingCard: View {
    let therapeutic: TherapeuticsBase?
    @Binding var doseAmount: Double?
    @Binding var selectedUnitId: String
    @Binding var dosesPerDay: Int
    let availableUnits: [TherapeuticUnitOption]
    let color: Color
    let fallbackUnit: String?

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var stepValue: Double {
        // Intelligent step based on unit type
        switch selectedUnitId.lowercased() {
        case "mcg", "microgram":
            return 10
        case "mg", "milligram":
            return 25
        case "g", "gram":
            return 0.5
        case "ml", "milliliter":
            return 0.5
        case "iu":
            return 100
        default:
            return 1
        }
    }

    private var currentSymbol: String {
        if let unit = availableUnits.first(where: { $0.unitId == selectedUnitId }) {
            return unit.symbol
        }
        return fallbackUnit ?? selectedUnitId
    }

    private var currentDisplayName: String {
        if let unit = availableUnits.first(where: { $0.unitId == selectedUnitId }) {
            return unit.displayName
        }
        return selectedUnitId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Dosing")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Amount + Unit row
            HStack(spacing: 12) {
                // Styled text field with ± buttons
                HStack(spacing: 0) {
                    Button {
                        adjustDose(-stepValue)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                            .frame(width: 36, height: 36)
                            .background(color.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    TextField("0", text: $textValue)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 70)
                        .focused($isFocused)
                        .onChange(of: textValue) { _, newValue in
                            // Filter to digits and decimal
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue {
                                textValue = filtered
                            }
                            if let value = Double(filtered) {
                                doseAmount = value
                            } else if filtered.isEmpty {
                                doseAmount = nil
                            }
                        }

                    Button {
                        adjustDose(stepValue)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                            .frame(width: 36, height: 36)
                            .background(color.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? color : Color.clear, lineWidth: 2)
                )
                .cornerRadius(10)

                // Unit picker (Menu style, from DB)
                if availableUnits.isEmpty {
                    // Fallback: show static unit from therapeutic
                    Text(fallbackUnit ?? "mg")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                } else {
                    Menu {
                        ForEach(availableUnits) { unit in
                            Button {
                                selectedUnitId = unit.unitId
                            } label: {
                                HStack {
                                    Text(unit.displayName)
                                    if unit.isDefault {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentSymbol)
                                .foregroundColor(color)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }

            // Doses per day stepper
            HStack {
                Text("Doses per day")
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if dosesPerDay > 1 { dosesPerDay -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(dosesPerDay > 1 ? color : .gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(dosesPerDay <= 1)

                    Text("\(dosesPerDay)")
                        .font(.headline)
                        .frame(minWidth: 24)

                    Button {
                        if dosesPerDay < 10 { dosesPerDay += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(dosesPerDay < 10 ? color : .gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(dosesPerDay >= 10)
                }
            }
            .padding(.top, 4)

            // Typical dose hint from therapeutic
            if let therapeutic = therapeutic, !therapeutic.doseRangeDescription.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Typical: \(therapeutic.doseRangeDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if let amount = doseAmount {
                textValue = formatDoseAmount(amount)
            }
        }
        .onChange(of: doseAmount) { _, newValue in
            if !isFocused, let amount = newValue {
                textValue = formatDoseAmount(amount)
            }
        }
    }

    private func adjustDose(_ delta: Double) {
        let current = doseAmount ?? 0
        let newValue = max(0, current + delta)
        doseAmount = newValue
        textValue = formatDoseAmount(newValue)
    }

    private func formatDoseAmount(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TherapeuticDosingCard(
            therapeutic: nil,
            doseAmount: .constant(500),
            selectedUnitId: .constant("mg"),
            dosesPerDay: .constant(1),
            availableUnits: [],
            color: .green,
            fallbackUnit: "mg"
        )

        TherapeuticDosingCard(
            therapeutic: nil,
            doseAmount: .constant(1000),
            selectedUnitId: .constant("iu"),
            dosesPerDay: .constant(2),
            availableUnits: [
                TherapeuticUnitOption(
                    id: UUID(),
                    therapeuticName: "Vitamin D3",
                    unitId: "iu",
                    conversionToBaseFactor: 1,
                    isDefault: true,
                    isAvailable: true,
                    baseUnitId: "iu",
                    notes: nil,
                    unitsBase: UnitsBaseInfo(symbol: "IU", uiDisplay: "International Units")
                ),
                TherapeuticUnitOption(
                    id: UUID(),
                    therapeuticName: "Vitamin D3",
                    unitId: "mcg",
                    conversionToBaseFactor: 40,
                    isDefault: false,
                    isAvailable: true,
                    baseUnitId: "iu",
                    notes: "1 mcg = 40 IU",
                    unitsBase: UnitsBaseInfo(symbol: "mcg", uiDisplay: "micrograms")
                )
            ],
            color: .orange,
            fallbackUnit: "IU"
        )
    }
    .padding()
}
