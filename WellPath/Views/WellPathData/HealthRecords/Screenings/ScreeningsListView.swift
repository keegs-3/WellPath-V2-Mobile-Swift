//
//  ScreeningsListView.swift
//  WellPath
//
//  Screenings & Immunizations section with triple-view architecture:
//  1. Calendar view for visual scheduling
//  2. Status list (up-to-date, due soon, overdue)
//  3. Immunization records
//

import SwiftUI

struct ScreeningsListView: View {
    @StateObject private var viewModel = ScreeningsViewModel()
    @State private var selectedTab = 0
    @State private var showingAddScreening = false
    @State private var showingAddImmunization = false

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Calendar").tag(0)
                Text("Status").tag(1)
                Text("Immunizations").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selection
            TabView(selection: $selectedTab) {
                ScreeningsCalendarView(viewModel: viewModel)
                    .tag(0)

                ScreeningsStatusView(viewModel: viewModel)
                    .tag(1)

                ImmunizationsView(viewModel: viewModel, showingAddSheet: $showingAddImmunization)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Screenings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddScreening = true
                    } label: {
                        Label("Add Screening", systemImage: "heart.text.square")
                    }

                    Button {
                        showingAddImmunization = true
                    } label: {
                        Label("Add Immunization", systemImage: "syringe")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddScreening) {
            AddScreeningRecordView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddImmunization) {
            AddImmunizationRecordView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadAllData()
        }
    }
}

// MARK: - Calendar View

struct ScreeningsCalendarView: View {
    @ObservedObject var viewModel: ScreeningsViewModel
    @State private var selectedDate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calendar
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Upcoming Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.dueSoonScreenings.isEmpty && viewModel.overdueScreenings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("No upcoming screenings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            // Overdue first
                            ForEach(viewModel.overdueScreenings) { screening in
                                ScreeningEventRow(
                                    name: viewModel.getScreeningName(for: screening.screeningTypeId),
                                    date: screening.nextDueDate ?? Date(),
                                    status: .overdue,
                                    color: .red
                                )

                                if screening.id != viewModel.overdueScreenings.last?.id ||
                                    !viewModel.dueSoonScreenings.isEmpty {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // Due soon
                            ForEach(viewModel.dueSoonScreenings) { screening in
                                ScreeningEventRow(
                                    name: viewModel.getScreeningName(for: screening.screeningTypeId),
                                    date: screening.nextDueDate ?? Date(),
                                    status: .dueSoon,
                                    color: .orange
                                )

                                if screening.id != viewModel.dueSoonScreenings.last?.id {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.top)
        }
    }
}

// MARK: - Status View

struct ScreeningsStatusView: View {
    @ObservedObject var viewModel: ScreeningsViewModel

    var body: some View {
        List {
            if !viewModel.upToDateScreenings.isEmpty {
                Section {
                    ForEach(viewModel.upToDateScreenings) { screening in
                        ScreeningStatusRow(
                            name: viewModel.getScreeningName(for: screening.screeningTypeId),
                            lastDate: screening.screeningDate,
                            nextDate: screening.nextDueDate,
                            status: .upToDate
                        )
                    }
                } header: {
                    Label("Up to Date", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if !viewModel.dueSoonScreenings.isEmpty {
                Section {
                    ForEach(viewModel.dueSoonScreenings) { screening in
                        ScreeningStatusRow(
                            name: viewModel.getScreeningName(for: screening.screeningTypeId),
                            lastDate: screening.screeningDate,
                            nextDate: screening.nextDueDate,
                            status: .dueSoon
                        )
                    }
                } header: {
                    Label("Due Soon", systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }

            if !viewModel.overdueScreenings.isEmpty {
                Section {
                    ForEach(viewModel.overdueScreenings) { screening in
                        ScreeningStatusRow(
                            name: viewModel.getScreeningName(for: screening.screeningTypeId),
                            lastDate: screening.screeningDate,
                            nextDate: screening.nextDueDate,
                            status: .overdue
                        )
                    }
                } header: {
                    Label("Overdue", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            if viewModel.screenings.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No screenings recorded")
                            .font(.headline)

                        Text("Add your preventive screenings to track your health status and get reminders.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }

            // Available screenings section
            if !viewModel.screeningTypes.isEmpty {
                Section("Available Screenings") {
                    ForEach(viewModel.screeningTypes.filter { type in
                        !viewModel.screenings.contains(where: { $0.screeningTypeId == type.screeningTypeId })
                    }) { screeningType in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(screeningType.screeningName)
                                    .font(.headline)
                                if let freq = screeningType.recommendedFrequencyMonths {
                                    Text("Recommended every \(freq) months")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Immunizations View

struct ImmunizationsView: View {
    @ObservedObject var viewModel: ScreeningsViewModel
    @Binding var showingAddSheet: Bool

    var recentImmunizations: [PatientImmunization] {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        return viewModel.immunizations.filter { $0.administrationDate >= threeMonthsAgo }
    }

    var olderImmunizations: [PatientImmunization] {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        return viewModel.immunizations.filter { $0.administrationDate < threeMonthsAgo }
    }

    var body: some View {
        List {
            if !recentImmunizations.isEmpty {
                Section("Recent") {
                    ForEach(recentImmunizations) { immunization in
                        ImmunizationRow(immunization: immunization)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.deleteImmunization(id: recentImmunizations[index].id)
                            }
                        }
                    }
                }
            }

            if !olderImmunizations.isEmpty {
                Section("All Records") {
                    ForEach(olderImmunizations) { immunization in
                        ImmunizationRow(immunization: immunization)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.deleteImmunization(id: olderImmunizations[index].id)
                            }
                        }
                    }
                }
            }

            if viewModel.immunizations.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "syringe")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No immunizations recorded")
                            .font(.headline)

                        Text("Keep track of your vaccines by adding immunization records.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }

            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Immunization Record", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Add Screening Record View

struct AddScreeningRecordView: View {
    @ObservedObject var viewModel: ScreeningsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScreeningTypeId: String = ""
    @State private var screeningDate = Date()
    @State private var setNextDue = true
    @State private var nextDueDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Screening Type") {
                    Picker("Type", selection: $selectedScreeningTypeId) {
                        Text("Select...").tag("")
                        ForEach(viewModel.screeningTypes) { type in
                            Text(type.screeningName).tag(type.screeningTypeId)
                        }
                    }
                }

                Section("Date Completed") {
                    DatePicker("Date", selection: $screeningDate, displayedComponents: .date)
                }

                Section {
                    Toggle("Set Next Due Date", isOn: $setNextDue)

                    if setNextDue {
                        DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Screening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addScreening(
                                screeningTypeId: selectedScreeningTypeId,
                                screeningDate: screeningDate,
                                nextDueDate: setNextDue ? nextDueDate : nil,
                                notes: notes.isEmpty ? nil : notes
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedScreeningTypeId.isEmpty)
                }
            }
            .onChange(of: selectedScreeningTypeId) { _, newValue in
                // Auto-calculate next due date based on screening type frequency
                if let type = viewModel.screeningTypes.first(where: { $0.screeningTypeId == newValue }),
                   let frequency = type.recommendedFrequencyMonths {
                    nextDueDate = Calendar.current.date(
                        byAdding: .month,
                        value: frequency,
                        to: screeningDate
                    ) ?? Date()
                }
            }
        }
    }
}

// MARK: - Add Immunization Record View

struct AddImmunizationRecordView: View {
    @ObservedObject var viewModel: ScreeningsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVaccineTypeId: String = ""
    @State private var customVaccineName = ""
    @State private var administrationDate = Date()
    @State private var doseNumber = 1
    @State private var totalDoses = 1
    @State private var provider = ""
    @State private var location = ""
    @State private var lotNumber = ""
    @State private var notes = ""

    var vaccineName: String {
        if selectedVaccineTypeId == "OTHER" {
            return customVaccineName
        }
        return viewModel.vaccineTypes.first(where: { $0.vaccineTypeId == selectedVaccineTypeId })?.vaccineName ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vaccine") {
                    Picker("Vaccine Type", selection: $selectedVaccineTypeId) {
                        Text("Select...").tag("")
                        ForEach(viewModel.vaccineTypes) { type in
                            Text(type.vaccineName).tag(type.vaccineTypeId)
                        }
                    }

                    if selectedVaccineTypeId == "OTHER" {
                        TextField("Vaccine Name", text: $customVaccineName)
                    }
                }

                Section("Administration") {
                    DatePicker("Date", selection: $administrationDate, displayedComponents: .date)

                    Stepper("Dose \(doseNumber) of \(totalDoses)", value: $doseNumber, in: 1...totalDoses)

                    Stepper("Total Doses: \(totalDoses)", value: $totalDoses, in: 1...5)
                }

                Section("Provider (Optional)") {
                    TextField("Provider/Doctor", text: $provider)
                    TextField("Location", text: $location)
                    TextField("Lot Number", text: $lotNumber)
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Immunization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addImmunization(
                                vaccineTypeId: selectedVaccineTypeId,
                                vaccineName: vaccineName,
                                administrationDate: administrationDate,
                                doseNumber: doseNumber,
                                totalDoses: totalDoses,
                                provider: provider.isEmpty ? nil : provider,
                                location: location.isEmpty ? nil : location,
                                lotNumber: lotNumber.isEmpty ? nil : lotNumber,
                                notes: notes.isEmpty ? nil : notes
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedVaccineTypeId.isEmpty || (selectedVaccineTypeId == "OTHER" && customVaccineName.isEmpty))
                }
            }
            .onChange(of: selectedVaccineTypeId) { _, newValue in
                // Auto-set total doses based on vaccine type
                if let type = viewModel.vaccineTypes.first(where: { $0.vaccineTypeId == newValue }) {
                    totalDoses = type.totalDoses
                    doseNumber = min(doseNumber, totalDoses)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ScreeningEventRow: View {
    let name: String
    let date: Date
    let status: ScreeningStatus
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(status == .overdue ? "Overdue" : "Due Soon")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.15))
                .cornerRadius(6)
        }
        .padding()
    }
}

struct ScreeningStatusRow: View {
    let name: String
    let lastDate: Date?
    let nextDate: Date?
    let status: ScreeningStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let lastDate = lastDate {
                        Text("Last: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    if let nextDate = nextDate {
                        if lastDate != nil {
                            Text("\u{2022}")
                        }
                        Text("Next: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: status.icon)
                .foregroundColor(status.color)
        }
    }
}

struct ImmunizationRow: View {
    let immunization: PatientImmunization

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(immunization.vaccineName)
                    .font(.headline)

                if immunization.totalDoses > 1 {
                    Text("(\(immunization.doseNumber)/\(immunization.totalDoses))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text(immunization.administrationDate.formatted(date: .abbreviated, time: .omitted))
                if let provider = immunization.provider, !provider.isEmpty {
                    Text("\u{2022}")
                    Text(provider)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ScreeningsListView()
    }
}
