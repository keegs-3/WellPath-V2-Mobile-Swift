//
//  PersonalInfoViewModel.swift
//  WellPath
//
//  ViewModel for Personal Info screen - patient profile editing
//

import Foundation
import Supabase
import UIKit

/// Height display unit preference
enum HeightDisplayUnit: String, CaseIterable {
    case cm = "cm"
    case ftIn = "ft/in"

    var displayName: String {
        switch self {
        case .cm: return "Centimeters"
        case .ftIn: return "Feet & Inches"
        }
    }
}

/// Biological sex options
enum BiologicalSex: String, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"

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

    // Advanced test flags
    @Published var hasDexaScan: Bool = false
    @Published var hasTrudiagnosticTest: Bool = false
    @Published var muscleMassRating: Int = 3  // Default to average

    // Display preferences
    @Published var heightUnit: HeightDisplayUnit = .cm
    @Published var heightFeet: Int = 5
    @Published var heightInches: Int = 7

    // Latest weight from aggregation (read-only)
    @Published var latestWeightKg: Double?
    @Published var weightDisplayUnit: String = "kg"

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
        // Display in kg (canonical unit)
        return String(format: "%.1f kg", weight)
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
                firstName = details.firstName ?? ""
                lastName = details.lastName ?? ""
                email = details.email ?? ""
                phone = details.phone ?? ""

                if let sex = details.biologicalSex,
                   let sexEnum = BiologicalSex(rawValue: sex.lowercased()) {
                    biologicalSex = sexEnum
                }

                if let dobString = details.dateOfBirth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: dobString) {
                        dateOfBirth = date
                    }
                }

                if let height = details.heightCm {
                    heightCm = height
                    updateFeetInchesFromCm()
                }

                isAthlete = details.isAthlete ?? false

                // Load advanced test flags
                hasDexaScan = details.hasDexaScan ?? false
                hasTrudiagnosticTest = details.hasTrudiagnosticTest ?? false
                muscleMassRating = details.muscleMassRating ?? 3

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

            // Fetch latest weight from aggregation
            await loadLatestWeight(patientId: userId)

        } catch {
            self.error = "Failed to load profile: \(error.localizedDescription)"
            print("❌ Error loading personal info: \(error)")
        }

        isLoading = false
    }

    private func loadLatestWeight(patientId: UUID) async {
        do {
            struct WeightResult: Codable {
                let value: Double
                let periodStart: String

                enum CodingKeys: String, CodingKey {
                    case value
                    case periodStart = "period_start"
                }
            }

            let results: [WeightResult] = try await supabase
                .from("aggregation_results_cache")
                .select("value, period_start")
                .eq("patient_id", value: patientId.uuidString)
                .eq("agg_metric_id", value: "AGG_BODYWEIGHT")
                .eq("period_type", value: "daily")
                .order("period_start", ascending: false)
                .limit(1)
                .execute()
                .value

            if let latest = results.first {
                // Value is stored in kg (canonical unit)
                latestWeightKg = latest.value
                print("✅ Loaded latest weight: \(latest.value) kg")
            }
        } catch {
            print("⚠️ Could not load latest weight: \(error)")
            // Not a critical error, weight display is optional
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

    func savePersonalInfo() async -> Bool {
        guard let patientId = patientId else {
            error = "No patient ID available"
            return false
        }

        isSaving = true
        error = nil
        saveSuccess = false

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dobString = formatter.string(from: dateOfBirth)

            // Build update payload
            struct PatientUpdate: Encodable {
                let firstName: String?
                let lastName: String?
                let phone: String?
                let biologicalSex: String?
                let dateOfBirth: String?
                let heightCm: Double?
                let isAthlete: Bool?
                let hasDexaScan: Bool?
                let hasTrudiagnosticTest: Bool?
                let muscleMassRating: Int?

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                    case phone
                    case biologicalSex = "biological_sex"
                    case dateOfBirth = "date_of_birth"
                    case heightCm = "height_cm"
                    case isAthlete = "is_athlete"
                    case hasDexaScan = "has_dexa_scan"
                    case hasTrudiagnosticTest = "has_trudiagnostic_test"
                    case muscleMassRating = "muscle_mass_rating"
                }
            }

            let update = PatientUpdate(
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                phone: phone.isEmpty ? nil : phone,
                biologicalSex: biologicalSex.rawValue,
                dateOfBirth: dobString,
                heightCm: heightCm,
                isAthlete: isAthlete,
                hasDexaScan: hasDexaScan,
                hasTrudiagnosticTest: hasTrudiagnosticTest,
                muscleMassRating: hasDexaScan ? nil : muscleMassRating  // Only save rating if no DEXA
            )

            try await supabase
                .from("patients")
                .update(update)
                .eq("patient_id", value: patientId.uuidString)
                .execute()

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
