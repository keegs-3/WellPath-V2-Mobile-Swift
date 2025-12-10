//
//  ProfileViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

/// Patient basic info from patients table
/// Note: Characteristics (biological_sex, date_of_birth, height, etc.) are stored in patient_characteristics
struct PatientDetails: Codable {
    let patientId: UUID
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var profileImageUrl: String?
    let medicalPracticeId: UUID?
    let assignedClinicianId: UUID?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case profileImageUrl = "profile_image_url"
        case medicalPracticeId = "medical_practice_id"
        case assignedClinicianId = "assigned_clinician_id"
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var patientDetails: PatientDetails?
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    var fullName: String {
        let first = patientDetails?.firstName ?? ""
        let last = patientDetails?.lastName ?? ""
        if first.isEmpty && last.isEmpty {
            return "User"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }

    var email: String {
        patientDetails?.email ?? ""
    }

    var initials: String {
        let first = patientDetails?.firstName?.prefix(1).uppercased() ?? ""
        let last = patientDetails?.lastName?.prefix(1).uppercased() ?? ""
        if first.isEmpty && last.isEmpty {
            return "U"
        }
        return "\(first)\(last)"
    }

    func loadProfile() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch patient details
            let response: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            patientDetails = response.first

        } catch {
            self.error = "Failed to load profile: \(error.localizedDescription)"
            print("Error loading profile: \(error)")
        }

        isLoading = false
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }
}
