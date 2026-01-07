//
//  PersonalInfoView.swift
//  WellPath
//
//  Personal Info screen for editing patient profile data
//

import SwiftUI
import PhotosUI

struct PersonalInfoView: View {
    @StateObject private var viewModel = PersonalInfoViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveConfirmation = false
    @State private var showWeightEntry = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            // Profile Photo Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if let image = viewModel.profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 80, height: 80)

                                    Text(initials)
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundColor(.blue)
                                }

                                // Upload indicator
                                if viewModel.isUploadingImage {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 80, height: 80)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .disabled(viewModel.isUploadingImage)
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    await viewModel.uploadProfileImage(uiImage)
                                }
                            }
                        }

                        Text(viewModel.isUploadingImage ? "Uploading..." : "Edit Photo")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Practice & Clinician Section (read-only)
            if viewModel.practiceName != nil || viewModel.clinicianName != nil {
                Section("Care Team") {
                    if let practice = viewModel.practiceName {
                        HStack {
                            Text("Practice")
                            Spacer()
                            Text(practice)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let clinician = viewModel.clinicianName {
                        HStack {
                            Text("Clinician")
                            Spacer()
                            Text(clinician)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Basic Info Section
            Section("Basic Information") {
                TextField("First Name", text: $viewModel.firstName)
                    .textContentType(.givenName)
                    .autocapitalization(.words)

                TextField("Last Name", text: $viewModel.lastName)
                    .textContentType(.familyName)
                    .autocapitalization(.words)

                HStack {
                    Text("Email")
                    Spacer()
                    Text(viewModel.email)
                        .foregroundColor(.secondary)
                }

                TextField("Phone", text: $viewModel.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }

            // Health Profile Section
            Section("Health Profile") {
                Picker("Biological Sex", selection: $viewModel.biologicalSex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }

                DatePicker(
                    "Date of Birth",
                    selection: $viewModel.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )

                // Height with unit toggle
                heightSection

                // Weight - tappable to add entry
                Button(action: { showWeightEntry = true }) {
                    HStack {
                        Text("Weight")
                            .foregroundColor(.primary)
                        Spacer()
                        if let weight = viewModel.displayWeight {
                            Text(weight)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Add")
                                .foregroundColor(.blue)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Athlete Status Section
            Section {
                Toggle("Athlete Status", isOn: $viewModel.isAthlete)
            } footer: {
                Text("Athlete status adjusts healthy ranges for biomarkers like creatine kinase.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Additional Characteristics Section
            additionalCharacteristicsSection

            // Advanced Testing Section (extracted to reduce body complexity)
            advancedTestingSection

            // Account Security Section
            Section("Account Security") {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Change Password")
                    }
                }
            }
        }
        .navigationTitle("Personal Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        let success = await viewModel.savePersonalInfo()
                        if success {
                            showSaveConfirmation = true
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
            }
        }
        .sheet(isPresented: $showWeightEntry) {
            BodyWeightEntryView()
                .onDisappear {
                    Task {
                        await viewModel.refreshWeight()
                    }
                }
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your personal information has been updated.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .task {
            await viewModel.loadPersonalInfo()
        }
    }

    // MARK: - Height Section

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Height")
                Spacer()
                Picker("Unit", selection: $viewModel.heightUnit) {
                    ForEach(HeightDisplayUnit2.allCases, id: \.self) { unit in
                        Text(unit.shortLabel).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            if viewModel.heightUnit == .cm {
                // Wheel picker for cm
                HStack {
                    Picker("Centimeters", selection: Binding(
                        get: { Int(viewModel.heightCm) },
                        set: { viewModel.heightCm = Double($0) }
                    )) {
                        ForEach(100...250, id: \.self) { cm in
                            Text("\(cm) cm").tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .onChange(of: viewModel.heightCm) { _, _ in
                        viewModel.updateFeetInchesFromCm()
                    }
                }
            } else {
                // Wheel pickers for feet/inches
                HStack(spacing: 0) {
                    Picker("Feet", selection: $viewModel.heightFeet) {
                        ForEach(3...8, id: \.self) { feet in
                            Text("\(feet) ft").tag(feet)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                    Picker("Inches", selection: $viewModel.heightInches) {
                        ForEach(0...11, id: \.self) { inches in
                            Text("\(inches) in").tag(inches)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                }
                .onChange(of: viewModel.heightFeet) { _, _ in
                    viewModel.updateHeightFromFeetInches()
                }
                .onChange(of: viewModel.heightInches) { _, _ in
                    viewModel.updateHeightFromFeetInches()
                }
            }
        }
    }

    // MARK: - Additional Characteristics Section

    @ViewBuilder
    private var additionalCharacteristicsSection: some View {
        Section("Additional Information") {
            // Blood Type
            Picker("Blood Type", selection: $viewModel.bloodType) {
                ForEach(BloodType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            // Dominant Hand
            Picker("Dominant Hand", selection: $viewModel.dominantHand) {
                ForEach(DominantHand.allCases, id: \.self) { hand in
                    Text(hand.displayName).tag(hand)
                }
            }

            // Smoking Status
            Picker("Smoking Status", selection: $viewModel.smokingStatus) {
                ForEach(SmokingStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }

            // Wheelchair Use
            Toggle("Uses Wheelchair", isOn: $viewModel.wheelchairUse)

            // Menopausal Status - only show for females
            if viewModel.biologicalSex == .female {
                Picker("Menopausal Status", selection: $viewModel.menopausalStatus) {
                    ForEach(MenopausalStatus.allCases.filter { $0 != .notApplicable }, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }

                // Pregnancy Status - only show for pre-menopausal females
                if viewModel.menopausalStatus == .preMenopausal {
                    Picker("Pregnancy Status", selection: $viewModel.pregnancyStatus) {
                        ForEach(PregnancyStatus.allCases.filter { $0 != .notApplicable }, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Advanced Testing Section

    @ViewBuilder
    private var advancedTestingSection: some View {
        Section("Advanced Testing") {
            Toggle("Has DEXA Scan Results", isOn: $viewModel.hasDexaScan)
            Toggle("Has TruDiagnostic Test", isOn: $viewModel.hasTrudiagnosticTest)

            if !viewModel.hasDexaScan {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Muscle Mass Assessment")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Picker("Rating", selection: $viewModel.muscleMassRating) {
                        Text("1 - Well Below Average").tag(1)
                        Text("2 - Below Average").tag(2)
                        Text("3 - Average").tag(3)
                        Text("4 - Above Average").tag(4)
                        Text("5 - Well Above Average").tag(5)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    @ViewBuilder
    private var advancedTestingFooter: some View {
        if viewModel.hasDexaScan {
            Text("With DEXA scan results, you can enter actual ASMI values for accurate muscle mass scoring.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("Rate muscle mass relative to others of the same age and gender. This subjective rating is used for WellPath scoring when DEXA data is unavailable.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var initials: String {
        let first = viewModel.firstName.prefix(1).uppercased()
        let last = viewModel.lastName.prefix(1).uppercased()
        if first.isEmpty && last.isEmpty {
            return "U"
        }
        return "\(first)\(last)"
    }
}

#Preview {
    NavigationStack {
        PersonalInfoView()
    }
}
