//
//  ConditionsListView.swift
//  WellPath
//
//  Conditions & Limitations section with triple-view architecture:
//  1. Personal conditions (your diagnosed conditions)
//  2. Family history (hereditary conditions)
//  3. Functional limitations (physical restrictions)
//

import SwiftUI

struct ConditionsListView: View {
    @StateObject private var viewModel = ConditionsViewModel()
    @State private var selectedTab = 0
    @State private var showingAddCondition = false
    @State private var showingAddLimitation = false

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Personal").tag(0)
                Text("Family").tag(1)
                Text("Limitations").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selection
            TabView(selection: $selectedTab) {
                PersonalConditionsView(viewModel: viewModel, showingAddSheet: $showingAddCondition)
                    .tag(0)

                FamilyHistoryView(viewModel: viewModel, showingAddSheet: $showingAddCondition)
                    .tag(1)

                FunctionalLimitationsView(viewModel: viewModel, showingAddSheet: $showingAddLimitation)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Conditions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddCondition = true
                    } label: {
                        Label("Add Condition", systemImage: "cross.case")
                    }

                    Button {
                        showingAddLimitation = true
                    } label: {
                        Label("Add Limitation", systemImage: "figure.walk.motion")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCondition) {
            AddConditionSheetView(viewModel: viewModel, historyType: selectedTab == 0 ? "personal" : "family")
        }
        .sheet(isPresented: $showingAddLimitation) {
            AddLimitationSheetView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadAllData()
        }
    }
}

// MARK: - Personal Conditions View

struct PersonalConditionsView: View {
    @ObservedObject var viewModel: ConditionsViewModel
    @Binding var showingAddSheet: Bool

    var body: some View {
        List {
            if viewModel.personalConditions.isEmpty {
                Section {
                    EmptyConditionsCard(
                        icon: "cross.case",
                        title: "No Personal Conditions",
                        subtitle: "Add any medical conditions you've been diagnosed with.",
                        action: { showingAddSheet = true }
                    )
                }
            } else {
                // Group by category
                let grouped = Dictionary(grouping: viewModel.personalConditions) { $0.conditionCategory ?? "Other" }
                let sortedCategories = grouped.keys.sorted()

                ForEach(sortedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(grouped[category] ?? []) { condition in
                            ConditionRowView(condition: condition)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteCondition(conditionId: condition.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Personal Condition", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Family History View

struct FamilyHistoryView: View {
    @ObservedObject var viewModel: ConditionsViewModel
    @Binding var showingAddSheet: Bool

    var body: some View {
        List {
            if viewModel.familyConditions.isEmpty {
                Section {
                    EmptyConditionsCard(
                        icon: "figure.2.and.child.holdinghands",
                        title: "No Family History",
                        subtitle: "Add medical conditions from your immediate family members.",
                        action: { showingAddSheet = true }
                    )
                }
            } else {
                // Group by family member
                let grouped = Dictionary(grouping: viewModel.familyConditions) { $0.familyMemberRelationship ?? "Unknown" }
                let sortedRelations = grouped.keys.sorted()

                ForEach(sortedRelations, id: \.self) { relation in
                    Section(relation.capitalized) {
                        ForEach(grouped[relation] ?? []) { condition in
                            FamilyConditionRowView(condition: condition)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteCondition(conditionId: condition.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Family History", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Functional Limitations View

struct FunctionalLimitationsView: View {
    @ObservedObject var viewModel: ConditionsViewModel
    @Binding var showingAddSheet: Bool

    var body: some View {
        List {
            if viewModel.limitations.isEmpty {
                Section {
                    EmptyConditionsCard(
                        icon: "figure.walk.motion",
                        title: "No Functional Limitations",
                        subtitle: "Track any physical restrictions that affect your daily activities.",
                        action: { showingAddSheet = true }
                    )
                }
            } else {
                // Group by type
                let grouped = Dictionary(grouping: viewModel.limitations) { $0.limitationType }
                let sortedTypes = grouped.keys.sorted()

                ForEach(sortedTypes, id: \.self) { type in
                    let typeInfo = LimitationType(rawValue: type) ?? .other

                    Section {
                        ForEach(grouped[type] ?? []) { limitation in
                            LimitationRowView(limitation: limitation)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteLimitation(id: limitation.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Label(typeInfo.displayName, systemImage: typeInfo.icon)
                            .foregroundColor(typeInfo.color)
                    }
                }
            }

            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Functional Limitation", systemImage: "plus.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Add Condition Sheet

struct AddConditionSheetView: View {
    @ObservedObject var viewModel: ConditionsViewModel
    @Environment(\.dismiss) private var dismiss

    let historyType: String

    @State private var conditionName = ""
    @State private var conditionCategory = "Cardiovascular"
    @State private var familyRelation = "parent"
    @State private var diagnosisDate = Date()
    @State private var hasDate = false
    @State private var notes = ""

    let categories = [
        "Cardiovascular",
        "Metabolic",
        "Cancer",
        "Neurological",
        "Autoimmune",
        "Respiratory",
        "Mental Health",
        "Musculoskeletal",
        "Other"
    ]

    let familyRelations = [
        "parent",
        "sibling",
        "grandparent",
        "aunt/uncle",
        "child"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Condition Details") {
                    TextField("Condition Name", text: $conditionName)

                    Picker("Category", selection: $conditionCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                if historyType == "family" {
                    Section("Family Member") {
                        Picker("Relationship", selection: $familyRelation) {
                            ForEach(familyRelations, id: \.self) { relation in
                                Text(relation.capitalized).tag(relation)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Add Diagnosis Date", isOn: $hasDate)

                    if hasDate {
                        DatePicker("Date", selection: $diagnosisDate, displayedComponents: .date)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(historyType == "personal" ? "Add Condition" : "Add Family History")
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
                            await viewModel.addCondition(
                                conditionId: UUID().uuidString,
                                conditionName: conditionName,
                                conditionCategory: conditionCategory,
                                historyType: historyType,
                                familyMemberRelationship: historyType == "family" ? familyRelation : nil,
                                diagnosisDate: hasDate ? diagnosisDate : nil,
                                notes: notes.isEmpty ? nil : notes
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(conditionName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Limitation Sheet

struct AddLimitationSheetView: View {
    @ObservedObject var viewModel: ConditionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var limitationName = ""
    @State private var limitationType: LimitationType = .mobility
    @State private var description = ""
    @State private var severity: SeverityLevel = .mild
    @State private var onsetDate = Date()
    @State private var hasOnsetDate = false
    @State private var isTemporary = false
    @State private var expectedDuration = 3
    @State private var affectsActivities: Set<String> = []
    @State private var accommodationsNeeded = ""
    @State private var notes = ""

    let activities = [
        "Walking",
        "Running",
        "Lifting",
        "Climbing stairs",
        "Driving",
        "Reading",
        "Working at computer",
        "Sleeping",
        "Exercise"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Limitation Details") {
                    TextField("Name/Description", text: $limitationName)

                    Picker("Type", selection: $limitationType) {
                        ForEach(LimitationType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Severity", selection: $severity) {
                        ForEach(SeverityLevel.allCases, id: \.rawValue) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section {
                    Toggle("Is Temporary", isOn: $isTemporary)

                    if isTemporary {
                        Stepper("Expected Duration: \(expectedDuration) months", value: $expectedDuration, in: 1...24)
                    }
                }

                Section {
                    Toggle("Add Onset Date", isOn: $hasOnsetDate)

                    if hasOnsetDate {
                        DatePicker("Onset Date", selection: $onsetDate, displayedComponents: .date)
                    }
                }

                Section("Affects Activities") {
                    ForEach(activities, id: \.self) { activity in
                        HStack {
                            Text(activity)
                            Spacer()
                            if affectsActivities.contains(activity) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if affectsActivities.contains(activity) {
                                affectsActivities.remove(activity)
                            } else {
                                affectsActivities.insert(activity)
                            }
                        }
                    }
                }

                Section("Accommodations Needed (Optional)") {
                    TextField("Accommodations", text: $accommodationsNeeded, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Limitation")
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
                            await viewModel.addLimitation(
                                limitationType: limitationType.rawValue,
                                limitationName: limitationName,
                                description: description.isEmpty ? nil : description,
                                severity: severity.rawValue,
                                onsetDate: hasOnsetDate ? onsetDate : nil,
                                isTemporary: isTemporary,
                                expectedDurationMonths: isTemporary ? expectedDuration : nil,
                                affectsActivities: Array(affectsActivities),
                                accommodationsNeeded: accommodationsNeeded.isEmpty ? nil : accommodationsNeeded,
                                notes: notes.isEmpty ? nil : notes
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(limitationName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Row Views

struct ConditionRowView: View {
    let condition: PatientCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(condition.conditionName)
                    .font(.headline)

                Spacer()

                if condition.isActive == true {
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
            }

            if let date = condition.diagnosisDate {
                Text("Diagnosed: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = condition.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FamilyConditionRowView: View {
    let condition: PatientCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(condition.conditionName)
                .font(.headline)

            if let category = condition.conditionCategory {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = condition.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LimitationRowView: View {
    let limitation: FunctionalLimitation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(limitation.limitationName)
                    .font(.headline)

                Spacer()

                // Severity badge
                Text(limitation.severityLevel.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(limitation.severityLevel.color)
                    .cornerRadius(6)
            }

            if limitation.isTemporary, let months = limitation.expectedDurationMonths {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Temporary (\(months) months)")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            if let activities = limitation.affectsActivities, !activities.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                    Text("Affects: \(activities.prefix(3).joined(separator: ", "))")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            if let notes = limitation.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State Card

struct EmptyConditionsCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    NavigationStack {
        ConditionsListView()
    }
}
