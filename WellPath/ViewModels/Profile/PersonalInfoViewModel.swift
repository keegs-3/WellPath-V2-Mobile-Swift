//
//  PersonalInfoViewModel.swift
//  WellPath
//
//  ViewModel for Personal Info screen - patient profile editing
//

import Foundation
import Supabase
import UIKit

/// Biological sex options
enum BiologicalSex: String, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"

    var displayName: String {
        rawValue.capitalized
    }
}

/// Menopausal status options
enum MenopausalStatus: String, CaseIterable {
    case preMenopausal = "pre-menopausal"
    case periMenopausal = "peri-menopausal"
    case postMenopausal = "post-menopausal"
    case notApplicable = "not_applicable"

    var displayName: String {
        switch self {
        case .preMenopausal: return "Pre-Menopausal"
        case .periMenopausal: return "Peri-Menopausal"
        case .postMenopausal: return "Post-Menopausal"
        case .notApplicable: return "Not Applicable"
        }
    }
}

/// Smoking status options
enum SmokingStatus: String, CaseIterable {
    case never = "never"
    case former = "former"
    case current = "current"

    var displayName: String {
        rawValue.capitalized
    }
}

/// Blood type options
enum BloodType: String, CaseIterable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
    case unknown = "unknown"

    var displayName: String {
        self == .unknown ? "Unknown" : rawValue
    }
}

/// Pregnancy status options (for females)
enum PregnancyStatus: String, CaseIterable {
    case notPregnant = "not_pregnant"
    case pregnant = "pregnant"
    case postpartum = "postpartum"
    case notApplicable = "not_applicable"

    var displayName: String {
        switch self {
        case .notPregnant: return "Not Pregnant"
        case .pregnant: return "Pregnant"
        case .postpartum: return "Postpartum"
        case .notApplicable: return "Not Applicable"
        }
    }
}

/// Dominant hand options
enum DominantHand: String, CaseIterable {
    case right = "right"
    case left = "left"
    case ambidextrous = "ambidextrous"

    var displayName: String {
        rawValue.capitalized
    }
}

@MainActor
class PersonalInfoViewModel: ObservableObject {
    // Form fields
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var biologicalSex: BiologicalSex = .male
    @Published var dateOfBirth: Date = Date()
    @Published var heightCm: Double = 170.0
    @Published var isAthlete: Bool = false

    // Characteristics (static patient attributes from patient_characteristics table)
    @Published var menopausalStatus: MenopausalStatus = .notApplicable
    @Published var smokingStatus: SmokingStatus = .never
    @Published var bloodType: BloodType = .unknown
    @Published var wheelchairUse: Bool = false
    @Published var pregnancyStatus: PregnancyStatus = .notApplicable
    @Published var dominantHand: DominantHand = .right

    // Advanced test flags
    @Published var hasDexaScan: Bool = false
    @Published var hasTrudiagnosticTest: Bool = false
    @Published var muscleMassRating: Int = 3  // Default to average

    // Display preferences
    @Published var heightUnit: HeightDisplayUnit2 = .cm
    @Published var heightFeet: Int = 5
    @Published var heightInches: Int = 7

    // Latest weight from aggregation (read-only)
    @Published var latestWeightKg: Double?
    @Published var weightDisplayUnit: WeightDisplayUnit = .kg

    // Practice and clinician info (read-only lookups)
    @Published var practiceName: String?
    @Published var clinicianName: String?

    // Profile image
    @Published var profileImage: UIImage?
    @Published var isUploadingImage = false
    private var profileImageUrl: String?

    // State
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var saveSuccess = false

    private let supabase = SupabaseManager.shared.client
    private var patientId: UUID?

    // MARK: - Computed Properties

    var displayHeight: String {
        switch heightUnit {
        case .cm:
            return String(format: "%.0f cm", heightCm)
        case .ftIn:
            let totalInches = heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)' \(inches)\""
        }
    }

    var displayWeight: String? {
        guard let weight = latestWeightKg else { return nil }
        switch weightDisplayUnit {
        case .kg:
            return String(format: "%.1f kg", weight)
        case .lb:
            let lbs = weight * 2.20462
            return String(format: "%.1f lbs", lbs)
        }
    }

    var hasUnsavedChanges: Bool {
        // This could be expanded to track original values
        return true
    }

    // MARK: - Height Conversion

    func updateHeightFromFeetInches() {
        let totalInches = Double(heightFeet * 12 + heightInches)
        heightCm = totalInches * 2.54
    }

    func updateFeetInchesFromCm() {
        let totalInches = heightCm / 2.54
        heightFeet = Int(totalInches / 12)
        heightInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
    }

    // MARK: - Load Data

    func loadPersonalInfo() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id
            patientId = userId

            // Fetch patient details
            let response: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let details = response.first {
                // Load basic patient info from patients table
                firstName = details.firstName ?? ""
                lastName = details.lastName ?? ""
                email = details.email ?? ""
                phone = details.phone ?? ""

                // Load practice and clinician lookups
                if let practiceId = details.medicalPracticeId {
                    await loadPracticeName(practiceId: practiceId)
                }
                if let clinicianId = details.assignedClinicianId {
                    await loadClinicianName(clinicianId: clinicianId)
                }

                // Load profile image if URL exists
                if let imageUrl = details.profileImageUrl, !imageUrl.isEmpty {
                    profileImageUrl = imageUrl
                    await loadProfileImage(path: imageUrl)
                }
            }

            // Load unit preferences first (affects how height/weight are displayed)
            await loadUnitPreferences(patientId: userId)

            // Fetch latest weight from aggregation
            await loadLatestWeight(patientId: userId)

            // Load characteristics from patient_characteristics table
            // These may override values from patients table (characteristics is source of truth)
            await loadCharacteristics(patientId: userId)

        } catch {
            self.error = "Failed to load profile: \(error.localizedDescription)"
            print("❌ Error loading personal info: \(error)")
        }

        isLoading = false
    }

    private func loadLatestWeight(patientId: UUID) async {
        do {
            struct WeightResult: Codable {
                let canonicalValue: Double?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case startTime = "start_time"
                }
            }

            let results: [WeightResult] = try await supabase
                .from("patient_quantity_samples")
                .select("canonical_value, start_time")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: "bodyweight")
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let latest = results.first, let kg = latest.canonicalValue {
                // canonical_value is always in kg (canonical unit)
                latestWeightKg = kg
                print("✅ Loaded latest weight: \(kg) kg")
            }
        } catch {
            print("⚠️ Could not load latest weight: \(error)")
            // Not a critical error, weight display is optional
        }
    }

    /// Load characteristics from patient_characteristics table
    private func loadCharacteristics(patientId: UUID) async {
        do {
            struct CharacteristicResult: Codable {
                let characteristicTypeName: String
                let valueText: String?
                let valueNumeric: Double?
                let valueBoolean: Bool?
                let valueDate: String?

                enum CodingKeys: String, CodingKey {
                    case characteristicTypeName = "characteristic_type_name"
                    case valueText = "value_text"
                    case valueNumeric = "value_numeric"
                    case valueBoolean = "value_boolean"
                    case valueDate = "value_date"
                }
            }

            let results: [CharacteristicResult] = try await supabase
                .from("patient_characteristics")
                .select("characteristic_type_name, value_text, value_numeric, value_boolean, value_date")
                .eq("patient_id", value: patientId.uuidString)
                .execute()
                .value

            for char in results {
                switch char.characteristicTypeName {
                case "height":
                    if let height = char.valueNumeric {
                        heightCm = height
                        updateFeetInchesFromCm()
                    }
                case "biological_sex":
                    if let sex = char.valueText,
                       let sexEnum = BiologicalSex(rawValue: sex.lowercased()) {
                        biologicalSex = sexEnum
                    }
                case "date_of_birth":
                    if let dobString = char.valueDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let date = formatter.date(from: dobString) {
                            dateOfBirth = date
                        }
                    }
                case "athlete_status":
                    if let athlete = char.valueBoolean {
                        isAthlete = athlete
                    }
                case "menopausal_status":
                    if let status = char.valueText,
                       let statusEnum = MenopausalStatus(rawValue: status) {
                        menopausalStatus = statusEnum
                    }
                case "blood_type":
                    if let type = char.valueText,
                       let typeEnum = BloodType(rawValue: type) {
                        bloodType = typeEnum
                    }
                case "wheelchair_use":
                    if let wheelchair = char.valueBoolean {
                        wheelchairUse = wheelchair
                    }
                case "smoking_status":
                    if let status = char.valueText,
                       let statusEnum = SmokingStatus(rawValue: status) {
                        smokingStatus = statusEnum
                    }
                case "pregnancy_status":
                    if let status = char.valueText,
                       let statusEnum = PregnancyStatus(rawValue: status) {
                        pregnancyStatus = statusEnum
                    }
                case "dominant_hand":
                    if let hand = char.valueText,
                       let handEnum = DominantHand(rawValue: hand) {
                        dominantHand = handEnum
                    }
                case "has_dexa_scan":
                    if let hasDEXA = char.valueBoolean {
                        hasDexaScan = hasDEXA
                    }
                case "has_trudiagnostic_test":
                    if let hasTru = char.valueBoolean {
                        hasTrudiagnosticTest = hasTru
                    }
                case "muscle_mass_rating":
                    if let rating = char.valueNumeric {
                        muscleMassRating = Int(rating)
                    }
                default:
                    break
                }
            }

            print("✅ Loaded \(results.count) characteristics")
        } catch {
            print("⚠️ Could not load characteristics: \(error)")
            // Not critical - characteristics might not exist yet
        }
    }

    private func loadPracticeName(practiceId: UUID) async {
        do {
            struct PracticeResult: Codable {
                let practiceName: String

                enum CodingKeys: String, CodingKey {
                    case practiceName = "practice_name"
                }
            }

            let results: [PracticeResult] = try await supabase
                .from("medical_practices")
                .select("practice_name")
                .eq("id", value: practiceId.uuidString)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                practiceName = result.practiceName
                print("✅ Loaded practice: \(result.practiceName)")
            }
        } catch {
            print("⚠️ Could not load practice name: \(error)")
        }
    }

    private func loadClinicianName(clinicianId: UUID) async {
        do {
            struct ClinicianResult: Codable {
                let firstName: String?
                let lastName: String?

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                }
            }

            let results: [ClinicianResult] = try await supabase
                .from("practice_users")
                .select("first_name, last_name")
                .eq("user_id", value: clinicianId.uuidString)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                let first = result.firstName ?? ""
                let last = result.lastName ?? ""
                let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                if !fullName.isEmpty {
                    clinicianName = "Dr. \(fullName)"
                    print("✅ Loaded clinician: \(fullName)")
                }
            }
        } catch {
            print("⚠️ Could not load clinician name: \(error)")
        }
    }

    /// Load unit preferences from patient_unit_preferences table
    private func loadUnitPreferences(patientId: UUID) async {
        do {
            struct UnitPreferencesResult: Codable {
                let heightUnit: String?
                let weightUnit: String?

                enum CodingKeys: String, CodingKey {
                    case heightUnit = "height_unit"
                    case weightUnit = "weight_unit"
                }
            }

            let results: [UnitPreferencesResult] = try await supabase
                .from("patient_unit_preferences")
                .select("height_unit, weight_unit")
                .eq("patient_id", value: patientId.uuidString)
                .limit(1)
                .execute()
                .value

            if let prefs = results.first {
                if let height = prefs.heightUnit,
                   let heightEnum = HeightDisplayUnit2(rawValue: height) {
                    heightUnit = heightEnum
                    print("✅ Loaded height unit preference: \(height)")
                }
                if let weight = prefs.weightUnit,
                   let weightEnum = WeightDisplayUnit(rawValue: weight) {
                    weightDisplayUnit = weightEnum
                    print("✅ Loaded weight unit preference: \(weight)")
                }
            }
        } catch {
            print("⚠️ Could not load unit preferences: \(error)")
            // Not critical - use defaults
        }
    }

    /// Refresh weight after adding new entry
    func refreshWeight() async {
        guard let patientId = patientId else { return }
        await loadLatestWeight(patientId: patientId)
    }

    // MARK: - Profile Image

    private func loadProfileImage(path: String) async {
        do {
            let data = try await supabase.storage
                .from("avatars")
                .download(path: path)

            if let image = UIImage(data: data) {
                profileImage = image
                print("✅ Loaded profile image")
            }
        } catch {
            print("⚠️ Could not load profile image: \(error)")
        }
    }

    /// Upload a new profile image to Supabase Storage
    func uploadProfileImage(_ image: UIImage) async -> Bool {
        guard let patientId = patientId else { return false }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            error = "Failed to process image"
            return false
        }

        isUploadingImage = true

        do {
            // File path: {user_id}/avatar.jpg
            let filePath = "\(patientId.uuidString)/avatar.jpg"

            // Upload to storage (upsert to overwrite existing)
            try await supabase.storage
                .from("avatars")
                .upload(
                    filePath,
                    data: imageData,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            // Update the profile_image_url in patients table
            struct ImageUrlUpdate: Encodable {
                let profileImageUrl: String

                enum CodingKeys: String, CodingKey {
                    case profileImageUrl = "profile_image_url"
                }
            }

            try await supabase
                .from("patients")
                .update(ImageUrlUpdate(profileImageUrl: filePath))
                .eq("patient_id", value: patientId.uuidString)
                .execute()

            profileImageUrl = filePath
            profileImage = image
            print("✅ Profile image uploaded successfully")
            isUploadingImage = false
            return true

        } catch {
            self.error = "Failed to upload image: \(error.localizedDescription)"
            print("❌ Error uploading profile image: \(error)")
            isUploadingImage = false
            return false
        }
    }

    // MARK: - Save Data

    /// Save characteristics to patient_characteristics table using upsert
    private func saveCharacteristics(patientId: UUID) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dobString = formatter.string(from: dateOfBirth)

        // Build characteristic entries
        struct CharacteristicEntry: Encodable {
            let patientId: String
            let characteristicTypeName: String
            let valueText: String?
            let valueNumeric: Double?
            let valueBoolean: Bool?
            let valueDate: String?

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case characteristicTypeName = "characteristic_type_name"
                case valueText = "value_text"
                case valueNumeric = "value_numeric"
                case valueBoolean = "value_boolean"
                case valueDate = "value_date"
            }
        }

        let patientIdStr = patientId.uuidString
        let entries: [CharacteristicEntry] = [
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "height",
                valueText: nil,
                valueNumeric: heightCm,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "biological_sex",
                valueText: biologicalSex.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "date_of_birth",
                valueText: nil,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: dobString
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "athlete_status",
                valueText: nil,
                valueNumeric: nil,
                valueBoolean: isAthlete,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "menopausal_status",
                valueText: menopausalStatus.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "blood_type",
                valueText: bloodType.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "wheelchair_use",
                valueText: nil,
                valueNumeric: nil,
                valueBoolean: wheelchairUse,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "smoking_status",
                valueText: smokingStatus.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "pregnancy_status",
                valueText: pregnancyStatus.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "dominant_hand",
                valueText: dominantHand.rawValue,
                valueNumeric: nil,
                valueBoolean: nil,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "has_dexa_scan",
                valueText: nil,
                valueNumeric: nil,
                valueBoolean: hasDexaScan,
                valueDate: nil
            ),
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "has_trudiagnostic_test",
                valueText: nil,
                valueNumeric: nil,
                valueBoolean: hasTrudiagnosticTest,
                valueDate: nil
            ),
            // Only save muscle mass rating if no DEXA scan (it's a proxy)
            CharacteristicEntry(
                patientId: patientIdStr,
                characteristicTypeName: "muscle_mass_rating",
                valueText: nil,
                valueNumeric: hasDexaScan ? nil : Double(muscleMassRating),
                valueBoolean: nil,
                valueDate: nil
            )
        ]

        // Upsert each characteristic (Supabase SDK doesn't support batch upsert with conflict)
        for entry in entries {
            try await supabase
                .from("patient_characteristics")
                .upsert(entry, onConflict: "patient_id,characteristic_type_name")
                .execute()
        }

        print("✅ Saved \(entries.count) characteristics")
    }

    func savePersonalInfo() async -> Bool {
        guard let patientId = patientId else {
            error = "No patient ID available"
            return false
        }

        isSaving = true
        error = nil
        saveSuccess = false

        do {
            // Update patients table with basic info only (characteristics are in patient_characteristics)
            struct PatientUpdate: Encodable {
                let firstName: String?
                let lastName: String?
                let phone: String?

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                    case phone
                }
            }

            let update = PatientUpdate(
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                phone: phone.isEmpty ? nil : phone
            )

            try await supabase
                .from("patients")
                .update(update)
                .eq("patient_id", value: patientId.uuidString)
                .execute()

            print("✅ Basic info saved to patients table")

            // Save all characteristics to patient_characteristics table
            try await saveCharacteristics(patientId: patientId)

            print("✅ Personal info saved successfully")
            saveSuccess = true
            isSaving = false
            return true

        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
            print("❌ Error saving personal info: \(error)")
            isSaving = false
            return false
        }
    }
}
