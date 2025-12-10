//
//  BiomarkerEntryView.swift
//  WellPath
//
//  Manual data entry form for biomarker values
//  Saves to patient_clinical_samples table
//

import SwiftUI
import Supabase

struct BiomarkerEntryView: View {
    let biomarkerName: String  // Display name (e.g., "Lp(a)")
    let clinicalType: String   // Database clinical_type (e.g., "lpa")
    let unit: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var rangeLoader = BiomarkerValueLoader()
    @StateObject private var profileLoader = PatientProfileLoader()

    // Form fields
    @State private var valueText: String = ""
    @State private var sampleDateTime: Date = Date()
    @State private var labName: String = ""
    @State private var cyclePhase: String? = nil
    @State private var notes: String = ""

    // UI state
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let supabase = SupabaseManager.shared.client

    // Common lab options for quick selection
    private let commonLabs = ["LabCorp", "Quest Diagnostics", "BioReference", "Sonora Quest", "Other"]
    private let cyclePhases = ["Follicular", "Ovulatory", "Luteal"]

    private var parsedValue: Double? {
        Double(valueText)
    }

    /// Show cycle phase selector only for biomarkers with cycle-dependent ranges AND premenopausal females
    private var showCyclePhase: Bool {
        // Biomarkers that have cycle-dependent ranges (from biomarkers_detail.cycle_stage)
        let cycleDependent = ["Progesterone"]
        guard cycleDependent.contains(biomarkerName) else { return false }

        // Only show for premenopausal females
        return profileLoader.isPremenopausalFemale
    }

    var body: some View {
        NavigationStack {
            Form {
                // Value input section
                Section {
                    HStack {
                        TextField("Enter value", text: $valueText)
                            .keyboardType(.decimalPad)
                            .font(.title2)

                        Text(unit)
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                } header: {
                    Text("Value")
                }

                // Sample Date & Time
                Section {
                    DatePicker(
                        "Sample Date",
                        selection: $sampleDateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("When was the sample collected?")
                }

                // Cycle Phase (conditional)
                if showCyclePhase {
                    Section {
                        Picker("Cycle Phase", selection: Binding(
                            get: { cyclePhase ?? "Follicular" },
                            set: { cyclePhase = $0 }
                        )) {
                            ForEach(cyclePhases, id: \.self) { phase in
                                Text(phase).tag(phase)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Menstrual Cycle Phase")
                    } footer: {
                        Text("Reference ranges for \(biomarkerName) vary by cycle phase")
                            .font(.caption)
                    }
                }

                // Lab Name
                Section {
                    Picker("Laboratory", selection: $labName) {
                        Text("Select...").tag("")
                        ForEach(commonLabs, id: \.self) { lab in
                            Text(lab).tag(lab)
                        }
                    }

                    if labName == "Other" {
                        TextField("Lab name", text: $labName)
                    }
                } header: {
                    Text("Lab (Optional)")
                }

                // Notes section
                Section("Notes (Optional)") {
                    TextField("Fasting, time of day, medications...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Range information
                if let rangeInfo = rangeLoader.rangeInfo {
                    Section("Reference Ranges") {
                        ForEach(rangeInfo.sortedRanges) { range in
                            rangeRow(range)
                        }
                    }
                }
            }
            .navigationTitle("Add \(biomarkerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEntry() }
                    }
                    .disabled(parsedValue == nil || isSubmitting)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await rangeLoader.loadValue(for: biomarkerName)
                await profileLoader.loadProfile()
            }
        }
    }

    // MARK: - Subviews

    private func rangeRow(_ range: BiomarkerRangeDetail) -> some View {
        HStack {
            Circle()
                .fill(range.color)
                .frame(width: 10, height: 10)

            Text(range.rangeName)
                .font(.subheadline)

            Spacer()

            Text(rangeDescription(range))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func rangeDescription(_ range: BiomarkerRangeDetail) -> String {
        let low = range.rangeLow
        let high = range.rangeHigh

        if let l = low, let h = high {
            return "\(formatValue(l)) - \(formatValue(h))"
        } else if let l = low {
            return "> \(formatValue(l))"
        } else if let h = high {
            return "< \(formatValue(h))"
        }
        return ""
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        } else if value * 10 == (value * 10).rounded() {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    // MARK: - Save Entry

    private func saveEntry() async {
        guard let value = parsedValue else { return }
        isSubmitting = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Create clinical sample using the proper write model
            let sample = ClinicalSampleWrite.create(
                patientId: patientId,
                clinicalType: clinicalType,
                value: value,
                unit: unit,
                sampleTime: sampleDateTime,
                source: .manual,
                labName: labName.isEmpty ? nil : labName,
                cycleStage: showCyclePhase ? cyclePhase : nil
            )

            // Insert into patient_clinical_samples (the correct specialized table)
            try await supabase
                .from("patient_clinical_samples")
                .insert(sample)
                .execute()

            dismiss()

        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
            print("Error saving biomarker: \(error)")
        }

        isSubmitting = false
    }
}

// MARK: - Patient Profile Loader (for cycle phase eligibility)

@MainActor
class PatientProfileLoader: ObservableObject {
    @Published var isPremenopausalFemale = false
    @Published var biologicalSex: String?
    @Published var menopausalStatus: String?

    private let supabase = SupabaseManager.shared.client

    func loadProfile() async {
        do {
            let userId = try await supabase.auth.session.user.id

            // Patient characteristics are stored in patient_characteristics table
            struct Characteristic: Codable {
                let characteristicTypeName: String
                let valueText: String?

                enum CodingKeys: String, CodingKey {
                    case characteristicTypeName = "characteristic_type_name"
                    case valueText = "value_text"
                }
            }

            let characteristics: [Characteristic] = try await supabase
                .from("patient_characteristics")
                .select("characteristic_type_name, value_text")
                .eq("patient_id", value: userId)
                .in("characteristic_type_name", values: ["biological_sex", "menopausal_status"])
                .execute()
                .value

            for char in characteristics {
                switch char.characteristicTypeName {
                case "biological_sex":
                    biologicalSex = char.valueText
                case "menopausal_status":
                    menopausalStatus = char.valueText
                default:
                    break
                }
            }

            // Premenopausal female = female sex AND premenopausal status
            isPremenopausalFemale = (biologicalSex?.lowercased() == "female" || biologicalSex?.lowercased() == "f")
                && menopausalStatus?.lowercased() == "premenopausal"

        } catch {
            print("Error loading patient profile: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    BiomarkerEntryView(
        biomarkerName: "Albumin",
        clinicalType: "albumin",
        unit: "g/dL"
    )
}
