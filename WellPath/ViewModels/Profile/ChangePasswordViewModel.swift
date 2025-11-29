//
//  ChangePasswordViewModel.swift
//  WellPath
//
//  ViewModel for changing user password via Supabase Auth
//

import Foundation
import Supabase

@MainActor
class ChangePasswordViewModel: ObservableObject {
    @Published var newPassword = ""
    @Published var confirmPassword = ""

    @Published var isLoading = false
    @Published var error: String?
    @Published var success = false

    private let supabase = SupabaseManager.shared.client

    // MARK: - Validation

    var isValid: Bool {
        !newPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    var passwordStrength: PasswordStrength {
        guard !newPassword.isEmpty else { return .none }

        var score = 0

        // Length checks
        if newPassword.count >= 8 { score += 1 }
        if newPassword.count >= 12 { score += 1 }

        // Character variety
        if newPassword.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default: return .strong
        }
    }

    var validationMessage: String? {
        if newPassword.isEmpty {
            return nil
        }
        if newPassword.count < 8 {
            return "Password must be at least 8 characters"
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }

    // MARK: - Change Password

    func changePassword() async -> Bool {
        guard isValid else {
            error = validationMessage ?? "Please check your password"
            return false
        }

        isLoading = true
        error = nil
        success = false

        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            print("✅ Password changed successfully")
            success = true
            isLoading = false
            return true

        } catch {
            self.error = "Failed to change password: \(error.localizedDescription)"
            print("❌ Error changing password: \(error)")
            isLoading = false
            return false
        }
    }

    func reset() {
        newPassword = ""
        confirmPassword = ""
        error = nil
        success = false
    }
}

// MARK: - Password Strength

enum PasswordStrength {
    case none
    case weak
    case medium
    case strong

    var label: String {
        switch self {
        case .none: return ""
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var color: String {
        switch self {
        case .none: return "secondary"
        case .weak: return "red"
        case .medium: return "orange"
        case .strong: return "green"
        }
    }
}
