//
//  SleepEntryView.swift
//  WellPath
//
//  Shared entry form for logging sleep to patient_category_samples.
//  Used by all Sleep screens via wrapper views.
//

import SwiftUI
import Supabase

struct SleepEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SleepEntryViewModel()

    @State private var asleepStart = Date()
    @State private var asleepEnd = Date()
    @State private var includeTimeInBed = false
    @State private var inBedStart = Date()
    @State private var inBedEnd = Date()

    var asleepDuration: TimeInterval {
        asleepEnd.timeIntervalSince(asleepStart)
    }

    var asleepHours: Double {
        asleepDuration / 3600
    }

    var timeInBedDuration: TimeInterval {
        inBedEnd.timeIntervalSince(inBedStart)
    }

    var timeInBedHours: Double {
        timeInBedDuration / 3600
    }

    // Validation helpers
    var asleepStartRange: ClosedRange<Date> {
        // If including time in bed, asleep must start after bed start
        if includeTimeInBed {
            return inBedStart...Date.distantFuture
        }
        return Date.distantPast...Date.distantFuture
    }

    var asleepEndRange: ClosedRange<Date> {
        // Must be after asleep start
        let earliest = asleepStart.addingTimeInterval(60) // at least 1 minute after start
        // If including time in bed, must be before bed end
        if includeTimeInBed {
            // Make sure we have a valid range
            let latestAllowed = max(earliest.addingTimeInterval(60), inBedEnd)
            return earliest...latestAllowed
        }
        return earliest...Date.distantFuture
    }

    var inBedStartRange: PartialRangeThrough<Date> {
        // Must be before or equal to asleep start
        ...asleepStart
    }

    var inBedEndRange: ClosedRange<Date> {
        // Must be after bed start AND after asleep end
        let earliestFromBedStart = inBedStart.addingTimeInterval(60)
        let earliest = max(earliestFromBedStart, asleepEnd)
        return earliest...Date.distantFuture
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $asleepStart, in: asleepStartRange)
                    DatePicker("End", selection: $asleepEnd, in: asleepEndRange)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(String(format: "%.1f hours", asleepHours))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Time Asleep")
                }

                Section {
                    Toggle("Include Time in Bed", isOn: $includeTimeInBed)

                    if includeTimeInBed {
                        DatePicker("Start", selection: $inBedStart, in: inBedStartRange)
                        DatePicker("End", selection: $inBedEnd, in: inBedEndRange)

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(String(format: "%.1f hours", timeInBedHours))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Time in Bed (Optional)")
                } footer: {
                    Text("Time in bed includes time awake before falling asleep and after waking up.")
                }

                Section {
                    Button(action: saveSleep) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Sleep")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(asleepDuration <= 0 || viewModel.isLoading)
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .onChange(of: includeTimeInBed) { newValue in
                if newValue {
                    // Initialize in bed times to match asleep times
                    inBedStart = asleepStart
                    inBedEnd = asleepEnd
                }
            }
            .onChange(of: asleepStart) { newStart in
                // If asleep start is now after asleep end, adjust asleep end
                if newStart >= asleepEnd {
                    asleepEnd = newStart.addingTimeInterval(3600) // 1 hour later
                }
                // If including time in bed and asleep start is before in bed start, adjust in bed start
                if includeTimeInBed && newStart < inBedStart {
                    inBedStart = newStart
                }
            }
            .onChange(of: asleepEnd) { newEnd in
                // If asleep end is now before or at asleep start, adjust asleep start
                if newEnd <= asleepStart {
                    asleepStart = newEnd.addingTimeInterval(-3600) // 1 hour earlier
                }
                // If including time in bed and asleep end is after in bed end, adjust in bed end
                if includeTimeInBed && newEnd > inBedEnd {
                    inBedEnd = newEnd
                }
            }
            .onChange(of: inBedStart) { newStart in
                // If in bed start is after asleep start, adjust asleep start
                if newStart > asleepStart {
                    asleepStart = newStart
                }
            }
            .onChange(of: inBedEnd) { newEnd in
                // If in bed end is before asleep end, adjust asleep end
                if newEnd < asleepEnd {
                    asleepEnd = newEnd
                }
            }
        }
    }

    func saveSleep() {
        Task {
            // If user didn't specify time in bed, use time asleep as time in bed
            let bedStart = includeTimeInBed ? inBedStart : asleepStart
            let bedEnd = includeTimeInBed ? inBedEnd : asleepEnd

            let success = await viewModel.saveSleep(
                inBedStart: bedStart,
                inBedEnd: bedEnd,
                asleepStart: asleepStart,
                asleepEnd: asleepEnd
            )

            if success {
                dismiss()
            }
        }
    }
}

@MainActor
class SleepEntryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func saveSleep(inBedStart: Date, inBedEnd: Date, asleepStart: Date, asleepEnd: Date) async -> Bool {
        isLoading = true
        error = nil

        do {
            let userId = try await supabase.auth.session.user.id

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // For manual entry, we create a single "core" sleep stage covering the asleep period
            // (HealthKit provides detailed stages, but manual entry is simplified)
            var sleepSamples: [CategorySampleWrite] = []

            // Main sleep period as "core"
            sleepSamples.append(CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                value: SleepPeriodTypeKeys.core,
                startTime: asleepStart,
                endTime: asleepEnd,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: ["was_user_entered": .bool(true)],
                eventInstanceId: UUID()
            ))

            // If time in bed is different from asleep time, add awake periods
            if inBedStart < asleepStart {
                // Awake period before falling asleep
                sleepSamples.append(CategorySampleWrite.create(
                    patientId: userId,
                    categoryType: CategoryTypes.sleepPeriodTypes,
                    value: SleepPeriodTypeKeys.awake,
                    startTime: inBedStart,
                    endTime: asleepStart,
                    source: .wellpathInput,
                    timezone: deviceTimezone,
                    metadata: ["was_user_entered": .bool(true)],
                    eventInstanceId: UUID()
                ))
            }

            if asleepEnd < inBedEnd {
                // Awake period after waking up
                sleepSamples.append(CategorySampleWrite.create(
                    patientId: userId,
                    categoryType: CategoryTypes.sleepPeriodTypes,
                    value: SleepPeriodTypeKeys.awake,
                    startTime: asleepEnd,
                    endTime: inBedEnd,
                    source: .wellpathInput,
                    timezone: deviceTimezone,
                    metadata: ["was_user_entered": .bool(true)],
                    eventInstanceId: UUID()
                ))
            }

            // Insert all sleep samples
            try await supabase
                .from("patient_category_samples")
                .insert(sleepSamples)
                .execute()

            isLoading = false
            return true

        } catch {
            self.error = error.localizedDescription
            print("Error saving sleep: \(error)")
            isLoading = false
            return false
        }
    }
}

#Preview {
    SleepEntryView()
}
