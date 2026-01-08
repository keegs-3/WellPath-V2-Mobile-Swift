//
//  MyTherapeuticsView.swift
//  WellPath
//
//  Unified tracking view for all therapeutics (medications, supplements, peptides, hormones).
//  Apple Health-inspired design with calendar strip and dose logging.
//

import SwiftUI

struct MyTherapeuticsView: View {
    let color: Color

    @StateObject private var viewModel = MyTherapeuticsViewModel()
    @State private var showAddSheet = false
    @State private var showSkipReasonSheet = false
    @State private var pendingSkip: (PatientTherapeutic, TimeOfDay)?

    init(color: Color = Color(hex: "F4D284") ?? .yellow) {
        self.color = color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Calendar Strip
                CalendarStripView(
                    selectedDate: $viewModel.selectedDate,
                    dayStatus: viewModel.dayStatus,
                    accentColor: color
                )
                .onChange(of: viewModel.selectedDate) { _, newDate in
                    viewModel.selectDate(newDate)
                }

                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.activeTherapeutics.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 20) {
                        // Today's Schedule
                        todaysScheduleSection

                        // Your Therapeutics Summary
                        therapeuticsSummarySection

                        // Interactions Warning
                        if !viewModel.interactions.isEmpty {
                            interactionsSection
                        }
                    }
                    .padding()
                }
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle("My Therapeutics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TherapeuticSearchView()
        }
        .sheet(isPresented: $showSkipReasonSheet) {
            if let (therapeutic, timing) = pendingSkip {
                SkipReasonSheet(
                    therapeutic: therapeutic,
                    timing: timing,
                    onSkip: { reason in
                        Task {
                            await viewModel.logDose(
                                therapeutic: therapeutic,
                                timing: timing,
                                taken: false,
                                skipReason: reason
                            )
                        }
                        showSkipReasonSheet = false
                        pendingSkip = nil
                    },
                    onCancel: {
                        showSkipReasonSheet = false
                        pendingSkip = nil
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Today's Schedule Section

    private var todaysScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isToday ? "Today's Schedule" : formattedDate)
                    .font(.headline)
                Spacer()
            }

            // Time of day groups
            ForEach(TimeOfDay.allCases) { timeOfDay in
                let therapeutics = therapeuticsFor(timeOfDay)
                if !therapeutics.isEmpty {
                    TimeOfDaySection(
                        timeOfDay: timeOfDay,
                        therapeutics: therapeutics,
                        viewModel: viewModel,
                        onSkip: { therapeutic in
                            pendingSkip = (therapeutic, timeOfDay)
                            showSkipReasonSheet = true
                        }
                    )
                }
            }

            if viewModel.morningTherapeutics.isEmpty &&
               viewModel.middayTherapeutics.isEmpty &&
               viewModel.eveningTherapeutics.isEmpty &&
               viewModel.bedtimeTherapeutics.isEmpty {
                Text("No scheduled doses for this day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }

    private var formattedDate: String {
        viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func therapeuticsFor(_ timeOfDay: TimeOfDay) -> [PatientTherapeutic] {
        switch timeOfDay {
        case .morning: return viewModel.morningTherapeutics
        case .midday: return viewModel.middayTherapeutics
        case .evening: return viewModel.eveningTherapeutics
        case .bedtime: return viewModel.bedtimeTherapeutics
        }
    }

    // MARK: - Therapeutics Summary Section

    private var therapeuticsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Therapeutics")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.activeTherapeutics.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                if !viewModel.medications.isEmpty {
                    TherapeuticTypeSummaryRow(
                        type: .medication,
                        count: viewModel.medications.count
                    )
                }
                if !viewModel.supplements.isEmpty {
                    TherapeuticTypeSummaryRow(
                        type: .supplement,
                        count: viewModel.supplements.count
                    )
                }
                if !viewModel.peptides.isEmpty {
                    TherapeuticTypeSummaryRow(
                        type: .peptide,
                        count: viewModel.peptides.count
                    )
                }
                if !viewModel.hormones.isEmpty {
                    TherapeuticTypeSummaryRow(
                        type: .hormone,
                        count: viewModel.hormones.count
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Interactions Section

    private var interactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Drug Interactions")
                    .font(.headline)
                Spacer()
            }

            ForEach(viewModel.interactions) { interaction in
                InteractionCard(interaction: interaction)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty & Loading States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No Therapeutics")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add your medications, supplements, peptides, and hormones to track your daily doses.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAddSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Therapeutic")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading therapeutics...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Calendar Strip View

struct CalendarStripView: View {
    @Binding var selectedDate: Date
    let dayStatus: (Date) -> DayLogStatus
    var accentColor: Color = .blue

    private let calendar = Calendar.current
    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    DayPill(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        status: dayStatus(date),
                        accentColor: accentColor
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(WellPathColors.cardBackground)
    }
}

struct DayPill: View {
    let date: Date
    let isSelected: Bool
    let status: DayLogStatus
    var accentColor: Color = .blue

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            Text(dayOfWeek)
                .font(.caption2)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(width: 36, height: 36)

                Text(dayNumber)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
            }

            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Time of Day Section

struct TimeOfDaySection: View {
    let timeOfDay: TimeOfDay
    let therapeutics: [PatientTherapeutic]
    let viewModel: MyTherapeuticsViewModel
    let onSkip: (PatientTherapeutic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: timeOfDay.icon)
                    .foregroundColor(timeOfDay.color)
                Text(timeOfDay.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 4)

            // Dose cards
            ForEach(therapeutics) { therapeutic in
                DoseLogCard(
                    therapeutic: therapeutic,
                    timing: timeOfDay,
                    log: viewModel.isLogged(
                        therapeutic: therapeutic,
                        timing: timeOfDay,
                        on: viewModel.selectedDate
                    ),
                    onTaken: {
                        Task {
                            await viewModel.logDose(
                                therapeutic: therapeutic,
                                timing: timeOfDay,
                                taken: true
                            )
                        }
                    },
                    onSkip: {
                        onSkip(therapeutic)
                    },
                    onUndo: { log in
                        Task {
                            await viewModel.undoLog(log)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Dose Log Card

struct DoseLogCard: View {
    let therapeutic: PatientTherapeutic
    let timing: TimeOfDay
    let log: TherapeuticLog?
    let onTaken: () -> Void
    let onSkip: () -> Void
    let onUndo: (TherapeuticLog) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(therapeutic.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: therapeutic.type.icon)
                    .font(.title3)
                    .foregroundColor(therapeutic.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(therapeutic.therapeuticName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(therapeutic.doseDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status / Actions
            if let log = log {
                // Already logged
                HStack(spacing: 8) {
                    if log.taken {
                        Label("Taken", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Skipped", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Button {
                        onUndo(log)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Actions
                HStack(spacing: 8) {
                    Button {
                        onTaken()
                    } label: {
                        Text("Taken")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }

                    Button {
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Skip Reason Sheet

struct SkipReasonSheet: View {
    let therapeutic: PatientTherapeutic
    let timing: TimeOfDay
    let onSkip: (String?) -> Void
    let onCancel: () -> Void

    @State private var reason = ""

    private let quickReasons = [
        "Ran out",
        "Side effects",
        "Forgot",
        "Doctor's orders",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Why are you skipping \(therapeutic.therapeuticName)?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                // Quick reasons
                VStack(spacing: 8) {
                    ForEach(quickReasons, id: \.self) { quickReason in
                        Button {
                            onSkip(quickReason)
                        } label: {
                            HStack {
                                Text(quickReason)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom reason
                TextField("Other reason (optional)", text: $reason)
                    .textFieldStyle(.roundedBorder)

                Spacer()
            }
            .padding()
            .navigationTitle("Skip Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onSkip(reason.isEmpty ? nil : reason)
                    }
                }
            }
        }
    }
}

// MARK: - Therapeutic Type Summary Row

struct TherapeuticTypeSummaryRow: View {
    let type: TherapeuticType
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .frame(width: 24)

            Text(type.displayNamePlural)
                .font(.subheadline)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Interaction Card

struct InteractionCard: View {
    let interaction: DrugInteraction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: interaction.severityIcon)
                    .foregroundColor(interaction.severityColor)

                Text(interaction.severity?.uppercased() ?? "UNKNOWN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(interaction.severityColor)

                Spacer()
            }

            Text("\(interaction.drug1Name) + \(interaction.drug2Name)")
                .font(.subheadline)
                .fontWeight(.medium)

            if let effect = interaction.clinicalEffect {
                Text(effect)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let management = interaction.management {
                Text(management)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(interaction.severityColor.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        MyTherapeuticsView(color: Color(hex: "F4D284") ?? .yellow)
    }
}
