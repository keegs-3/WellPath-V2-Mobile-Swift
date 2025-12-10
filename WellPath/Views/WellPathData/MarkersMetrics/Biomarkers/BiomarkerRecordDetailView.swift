//
//  BiomarkerRecordDetailView.swift
//  WellPath
//
//  Modal detail view for individual biomarker records
//  Mirrors Apple Health's Lab Result Record view
//

import SwiftUI

struct BiomarkerRecordDetailView: View {
    let biomarkerName: String
    let sample: BiomarkerSample
    let ranges: [BiomarkerRange]
    let unitDisplay: String
    let sectionColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var showFHIRData = false

    // Computed properties
    private var collectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: sample.sampleTime)
    }

    private var releasedDate: String? {
        // TODO: When released_at is added to BiomarkerSample model
        // guard let released = sample.releasedAt else { return nil }
        // return formatter.string(from: released)
        nil
    }

    private var status: BiomarkerStatus {
        for range in ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude
            if sample.value >= low && sample.value < high {
                return BiomarkerStatus.from(rangeName: range.rangeName)
            }
        }
        return .unknown
    }

    private var rangeName: String {
        for range in ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude
            if sample.value >= low && sample.value < high {
                return range.rangeName
            }
        }
        return "Unknown"
    }

    private var sourceDisplayName: String {
        switch sample.source {
        case "healthkit":
            return "Apple Health"
        case "manual":
            return "Manual Entry"
        case "clinician":
            return "Clinician Entry"
        case "integration":
            return "Connected Service"
        default:
            return sample.source ?? "Unknown"
        }
    }

    private var sourceIcon: String {
        switch sample.source {
        case "healthkit":
            return "heart.fill"
        case "manual":
            return "hand.draw.fill"
        case "clinician":
            return "stethoscope"
        case "integration":
            return "link"
        default:
            return "doc.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Value and Range
                    valueSection

                    // Details List
                    detailsSection

                    // Data Source
                    dataSourceSection

                    // FHIR Source Data (if available)
                    // TODO: Enable when fhir_data is added to model
                    // if sample.fhirData != nil {
                    //     fhirSourceSection
                    // }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Lab Result Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(biomarkerName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Collected \(collectedDate)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(sectionColor)
    }

    // MARK: - Value Section

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(sample.value))
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.primary)

                Text(unitDisplay)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Status badge
            Text(rangeName.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Range bar
            rangeBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - Range Bar

    private var rangeBar: some View {
        GeometryReader { geometry in
            let sortedRanges = ranges.sorted { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }
            let totalWidth = geometry.size.width

            // Calculate min/max for the bar from ranges
            let allLows = sortedRanges.compactMap { $0.rangeLow }
            let allHighs = sortedRanges.compactMap { $0.rangeHigh }
            let rangeMin = allLows.min() ?? 0
            let rangeMax = allHighs.max() ?? 150

            // Extend if patient value exceeds range bounds (for outliers)
            let minValue = min(rangeMin, sample.value)
            let maxValue = max(rangeMax, sample.value)
            let valueRange = maxValue - minValue

            // Find which range the patient value falls into
            let patientRangeId: UUID? = sortedRanges.first { range in
                let low = range.rangeLow ?? Double.leastNormalMagnitude
                let high = range.rangeHigh ?? Double.greatestFiniteMagnitude
                return sample.value >= low && sample.value < high
            }?.id

            ZStack(alignment: .leading) {
                // Range segments - only color the patient's range
                HStack(spacing: 0) {
                    // Add left padding if patient value is below range min
                    if sample.value < rangeMin {
                        let paddingWidth = ((rangeMin - minValue) / valueRange) * totalWidth
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: max(paddingWidth, 0))
                    }

                    ForEach(sortedRanges, id: \.id) { range in
                        let rangeLow = range.rangeLow ?? rangeMin
                        let rangeHigh = range.rangeHigh ?? rangeMax
                        let segmentWidth = ((rangeHigh - rangeLow) / valueRange) * totalWidth
                        let isPatientRange = range.id == patientRangeId

                        Rectangle()
                            .fill(isPatientRange ? rangeColor(for: range.rangeName) : Color.secondary.opacity(0.3))
                            .frame(width: max(segmentWidth, 2))
                    }

                    // Add right padding if patient value is above range max
                    if sample.value > rangeMax {
                        let paddingWidth = ((maxValue - rangeMax) / valueRange) * totalWidth
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: max(paddingWidth, 0))
                    }
                }
                .frame(width: totalWidth, height: 8)
                .clipShape(Capsule())

                // Value indicator
                let valuePosition = ((sample.value - minValue) / valueRange) * totalWidth
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(status.color, lineWidth: 3)
                    )
                    .offset(x: max(0, min(valuePosition - 8, totalWidth - 16)))

                // Range labels
                HStack {
                    Text(formatValue(minValue))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatValue(maxValue))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .offset(y: 16)
            }
        }
        .frame(height: 40)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Status row
            detailRow(label: "Status", value: "Final") // TODO: Use sample.resultStatus when available

            Divider()
                .padding(.leading, 16)

            // Released row (if available)
            if let released = releasedDate {
                detailRow(label: "Released", value: released)

                Divider()
                    .padding(.leading, 16)
            }

            // Interpretation row (based on our status)
            detailRow(label: "Interpretation", value: interpretationCode)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .padding(.top, 16)
    }

    private var interpretationCode: String {
        switch status {
        case .optimal:
            return "N" // Normal
        case .inRange:
            return "N"
        case .outOfRange:
            // Determine if high or low
            if let optimalRange = ranges.first(where: { $0.rangeName.uppercased() == "OPTIMAL" }) {
                let optimalMid = ((optimalRange.rangeLow ?? 0) + (optimalRange.rangeHigh ?? 100)) / 2
                return sample.value < optimalMid ? "L" : "H"
            }
            return "A" // Abnormal
        case .unknown:
            return "U"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Data Source Section

    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Source")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            HStack(spacing: 12) {
                // Source icon
                Image(systemName: sourceIcon)
                    .font(.title2)
                    .foregroundColor(sectionColor)
                    .frame(width: 44, height: 44)
                    .background(sectionColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(sourceDisplayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if sample.source == "healthkit" {
                        Text("Apple HealthKit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - FHIR Source Section (for future use)

    private var fhirSourceSection: some View {
        VStack(spacing: 0) {
            Button {
                showFHIRData = true
            } label: {
                HStack {
                    Text("FHIR Source Data")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .sheet(isPresented: $showFHIRData) {
            FHIRDataView(fhirData: [:]) // TODO: Pass actual fhir_data
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func rangeColor(for rangeName: String) -> Color {
        switch rangeName.uppercased() {
        case "OPTIMAL":
            return .green
        case "IN RANGE", "IN-RANGE":
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - FHIR Data View

struct FHIRDataView: View {
    let fhirData: [String: Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if fhirData.isEmpty {
                        Text("No FHIR data available")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // TODO: Pretty print FHIR JSON
                        Text("FHIR data will be displayed here")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("FHIR Source Data")
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

#Preview {
    BiomarkerRecordDetailView(
        biomarkerName: "Alkaline Phosphatase",
        sample: BiomarkerSample(
            id: UUID(),
            patientId: UUID(),
            clinicalType: "alkaline_phosphatase",
            value: 27,
            unit: "IU/L",
            sampleTime: Date(),
            source: "healthkit",
            labName: nil,
            labReferenceRangeLow: nil,
            labReferenceRangeHigh: nil,
            collectionMethod: nil
        ),
        ranges: [
            BiomarkerRange(
                id: UUID(),
                clinicalType: "alkaline_phosphatase",
                quantityType: nil,
                rangeName: "OUT OF RANGE",
                rangeNameBackend: "low_out",
                rangeLow: 0,
                rangeHigh: 39,
                frontendDisplay: "< 39",
                gender: nil,
                directionality: "optimal_range",
                ageLow: nil,
                ageHigh: nil,
                menopausalStatus: nil,
                cycleStage: nil,
                uniqueCondition: nil,
                rangeScore: nil
            ),
            BiomarkerRange(
                id: UUID(),
                clinicalType: "alkaline_phosphatase",
                quantityType: nil,
                rangeName: "OPTIMAL",
                rangeNameBackend: "optimal",
                rangeLow: 39,
                rangeHigh: 117,
                frontendDisplay: "39-117",
                gender: nil,
                directionality: "optimal_range",
                ageLow: nil,
                ageHigh: nil,
                menopausalStatus: nil,
                cycleStage: nil,
                uniqueCondition: nil,
                rangeScore: nil
            )
        ],
        unitDisplay: "IU/L",
        sectionColor: .orange
    )
}
