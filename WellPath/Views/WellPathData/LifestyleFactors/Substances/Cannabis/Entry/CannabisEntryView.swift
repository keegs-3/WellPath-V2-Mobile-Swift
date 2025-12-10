//
//  CannabisEntryView.swift
//  WellPath
//
//  Entry form for logging cannabis usage.
//  Uses different quantity_types per consumption method (flower, vape, edibles, etc.)
//

import SwiftUI
import Supabase

struct CannabisEntryView: View {
    @Environment(\.dismiss) var dismiss

    @State private var selectedDateTime = Date()
    @State private var count: Int = 1
    @State private var countText: String = "1"
    @State private var selectedType: CannabisType = .flower
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(isSaving)

                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))

            // Icon and Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedType.color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundColor(selectedType.color)
                }

                Text("Log Cannabis")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                Section("Consumption Method") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CannabisType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(selectedType.countLabel) {
                    HybridNumberInput(
                        value: $count,
                        textValue: $countText,
                        unit: count == 1 ? selectedType.unitSingular : selectedType.unitPlural,
                        color: selectedType.color,
                        range: 1...999,
                        isFocused: $isTextFieldFocused
                    )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            // Save button at bottom
            Button(action: {
                Task { await saveEntry() }
            }) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedType.color)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving)
        }
    }

    private func saveEntry() async {
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: selectedType.quantityType,
                value: Double(count),
                unit: selectedType.unit,
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await MainActor.run { dismiss() }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Cannabis Type Enum

enum CannabisType: String, CaseIterable {
    case flower
    case vape
    case edibles
    case concentrates
    case tinctures

    var displayName: String {
        switch self {
        case .flower: return "Flower/Smoke"
        case .vape: return "Vape"
        case .edibles: return "Edibles"
        case .concentrates: return "Concentrates/Dabs"
        case .tinctures: return "Tinctures/Oils"
        }
    }

    var quantityType: String {
        switch self {
        case .flower: return QuantityTypes.cannabisFlower
        case .vape: return QuantityTypes.cannabisVape
        case .edibles: return QuantityTypes.cannabisEdibles
        case .concentrates: return QuantityTypes.cannabisConcentrates
        case .tinctures: return QuantityTypes.cannabisTinctures
        }
    }

    var unit: String {
        switch self {
        case .flower: return "hits"
        case .vape: return "sessions"
        case .edibles: return "servings"
        case .concentrates: return "dabs"
        case .tinctures: return "doses"
        }
    }

    var unitSingular: String {
        switch self {
        case .flower: return "hit"
        case .vape: return "session"
        case .edibles: return "serving"
        case .concentrates: return "dab"
        case .tinctures: return "dose"
        }
    }

    var unitPlural: String {
        unit
    }

    var countLabel: String {
        switch self {
        case .flower: return "Number of Hits"
        case .vape: return "Number of Sessions"
        case .edibles: return "Number of Servings"
        case .concentrates: return "Number of Dabs"
        case .tinctures: return "Number of Doses"
        }
    }

    var aggId: String {
        switch self {
        case .flower: return "AGG_CANNABIS_FLOWER"
        case .vape: return "AGG_CANNABIS_VAPE"
        case .edibles: return "AGG_CANNABIS_EDIBLES"
        case .concentrates: return "AGG_CANNABIS_CONCENTRATES"
        case .tinctures: return "AGG_CANNABIS_TINCTURES"
        }
    }

    var color: Color {
        switch self {
        case .flower: return .green
        case .vape: return .cyan
        case .edibles: return .orange
        case .concentrates: return .yellow
        case .tinctures: return .purple
        }
    }
}

#Preview {
    CannabisEntryView()
}
