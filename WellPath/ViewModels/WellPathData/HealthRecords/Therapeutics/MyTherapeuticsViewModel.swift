//
//  MyTherapeuticsViewModel.swift
//  WellPath
//
//  ViewModel for the unified My Therapeutics tracking view.
//  Handles loading therapeutics, logs, and interactions.
//

import SwiftUI

// MARK: - Encodable Structs

private struct LogInsertData: Encodable {
    let patient_id: String
    let patient_therapeutic_id: String
    let logged_at: String
    let dose_amount: Double?
    let dose_unit: String?
    let timing: String?
    let taken: Bool
    let skip_reason: String?
    let notes: String?
    let source: String
}

@MainActor
class MyTherapeuticsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var therapeutics: [PatientTherapeutic] = []
    @Published var todaysLogs: [TherapeuticLog] = []
    @Published var weeklyLogs: [Date: [TherapeuticLog]] = [:]
    @Published var interactions: [DrugInteraction] = []
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Services

    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties - Active Therapeutics

    var activeTherapeutics: [PatientTherapeutic] {
        therapeutics.filter { $0.isActive == true }
    }

    var medications: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.therapeuticType == "MED" }
    }

    var supplements: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.therapeuticType == "SUP" }
    }

    var peptides: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.therapeuticType == "PEP" }
    }

    var hormones: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.therapeuticType == "HOR" }
    }

    // MARK: - Computed Properties - By Time of Day

    var morningTherapeutics: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.timingMorning == true }
    }

    var middayTherapeutics: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.timingMidday == true }
    }

    var eveningTherapeutics: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.timingEvening == true }
    }

    var bedtimeTherapeutics: [PatientTherapeutic] {
        activeTherapeutics.filter { $0.timingBedtime == true }
    }

    // MARK: - Computed Properties - Log Status

    func isLogged(therapeutic: PatientTherapeutic, timing: TimeOfDay, on date: Date) -> TherapeuticLog? {
        let calendar = Calendar.current
        let logs = date == selectedDate ? todaysLogs : (weeklyLogs[calendar.startOfDay(for: date)] ?? [])
        return logs.first { log in
            log.patientTherapeuticId == therapeutic.id && log.timing == timing.rawValue
        }
    }

    func dayStatus(for date: Date) -> DayLogStatus {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Future dates
        if startOfDay > calendar.startOfDay(for: Date()) {
            return .future
        }

        let logs = weeklyLogs[startOfDay] ?? []
        if logs.isEmpty {
            return .none
        }

        let expectedCount = countExpectedDoses()
        let takenCount = logs.filter { $0.taken }.count

        if takenCount >= expectedCount {
            return .complete
        } else if takenCount > 0 {
            return .partial
        } else {
            return .none
        }
    }

    private func countExpectedDoses() -> Int {
        var count = 0
        for therapeutic in activeTherapeutics where therapeutic.trackAdherence == true {
            if therapeutic.timingMorning == true { count += 1 }
            if therapeutic.timingMidday == true { count += 1 }
            if therapeutic.timingEvening == true { count += 1 }
            if therapeutic.timingBedtime == true { count += 1 }
        }
        return count
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        error = nil

        await loadTherapeutics()
        await loadLogsForDate(selectedDate)
        await loadWeeklyLogs()
        await loadInteractions()

        isLoading = false
    }

    func loadTherapeutics() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        do {
            therapeutics = try await supabase
                .from("patient_therapeutics")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("therapeutic_name")
                .execute()
                .value
        } catch {
            self.error = error.localizedDescription
            print("MyTherapeuticsViewModel: Error loading therapeutics - \(error)")
        }
    }

    func loadLogsForDate(_ date: Date) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let dateFormatter = ISO8601DateFormatter()

        do {
            todaysLogs = try await supabase
                .from("patient_therapeutic_logs")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .gte("logged_at", value: dateFormatter.string(from: startOfDay))
                .lt("logged_at", value: dateFormatter.string(from: endOfDay))
                .execute()
                .value
        } catch {
            print("MyTherapeuticsViewModel: Error loading logs - \(error)")
        }
    }

    func loadWeeklyLogs() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        let dateFormatter = ISO8601DateFormatter()

        do {
            let logs: [TherapeuticLog] = try await supabase
                .from("patient_therapeutic_logs")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .gte("logged_at", value: dateFormatter.string(from: weekAgo))
                .lt("logged_at", value: dateFormatter.string(from: tomorrow))
                .execute()
                .value

            // Group by date
            var grouped: [Date: [TherapeuticLog]] = [:]
            for log in logs {
                if let logDate = log.parsedLoggedAt {
                    let dayStart = calendar.startOfDay(for: logDate)
                    grouped[dayStart, default: []].append(log)
                }
            }
            weeklyLogs = grouped
        } catch {
            print("MyTherapeuticsViewModel: Error loading weekly logs - \(error)")
        }
    }

    func loadInteractions() async {
        guard !activeTherapeutics.isEmpty else {
            interactions = []
            return
        }

        let therapeuticNames = activeTherapeutics.map { $0.therapeuticName.lowercased() }

        do {
            // Query interactions where both drugs are in patient's list
            let allInteractions: [DrugInteraction] = try await supabase
                .from("drug_interactions")
                .select()
                .execute()
                .value

            // Filter to interactions between patient's therapeutics
            interactions = allInteractions.filter { interaction in
                let drug1 = interaction.drug1Name.lowercased()
                let drug2 = interaction.drug2Name.lowercased()
                return therapeuticNames.contains(drug1) && therapeuticNames.contains(drug2)
            }
        } catch {
            print("MyTherapeuticsViewModel: Error loading interactions - \(error)")
        }
    }

    // MARK: - Logging Actions

    func logDose(
        therapeutic: PatientTherapeutic,
        timing: TimeOfDay,
        taken: Bool,
        skipReason: String? = nil
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let now = Date()
        let dateFormatter = ISO8601DateFormatter()

        let insertData = LogInsertData(
            patient_id: userId.uuidString,
            patient_therapeutic_id: therapeutic.id.uuidString,
            logged_at: dateFormatter.string(from: now),
            dose_amount: therapeutic.doseAmount,
            dose_unit: therapeutic.doseUnit,
            timing: timing.rawValue,
            taken: taken,
            skip_reason: skipReason,
            notes: nil,
            source: "manual"
        )

        do {
            let newLog: TherapeuticLog = try await supabase
                .from("patient_therapeutic_logs")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value

            // Update local state
            todaysLogs.append(newLog)

            // Update weekly logs too
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: now)
            weeklyLogs[dayStart, default: []].append(newLog)

        } catch {
            print("MyTherapeuticsViewModel: Error logging dose - \(error)")
        }
    }

    func undoLog(_ log: TherapeuticLog) async {
        do {
            try await supabase
                .from("patient_therapeutic_logs")
                .delete()
                .eq("id", value: log.id.uuidString)
                .execute()

            // Update local state
            todaysLogs.removeAll { $0.id == log.id }

            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: log.logDate)
            weeklyLogs[dayStart]?.removeAll { $0.id == log.id }

        } catch {
            print("MyTherapeuticsViewModel: Error undoing log - \(error)")
        }
    }

    // MARK: - Date Navigation

    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await loadLogsForDate(date)
        }
    }
}

// MARK: - Day Log Status

enum DayLogStatus {
    case none
    case partial
    case complete
    case future

    var color: Color {
        switch self {
        case .none: return .gray
        case .partial: return .yellow
        case .complete: return .green
        case .future: return .clear
        }
    }
}
