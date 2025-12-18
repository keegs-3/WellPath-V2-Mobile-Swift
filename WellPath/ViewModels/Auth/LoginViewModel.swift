//
//  LoginViewModel.swift
//  WellPath
//
//  Handles authentication operations: sign in, sign up, password reset
//

import Foundation
import Supabase

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?

    private let supabase = SupabaseManager.shared.client

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        successMessage = nil

        do {
            try await supabase.auth.signIn(email: email, password: password)
            // Auth state will be handled by AuthStateManager
        } catch {
            self.error = mapAuthError(error)
            print("Login error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        isLoading = true
        error = nil
        successMessage = nil

        do {
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "wellpath://auth/reset")
            )
            successMessage = "Password reset link sent! Check your email."
        } catch {
            self.error = mapAuthError(error)
            print("Password reset error: \(error)")
        }

        isLoading = false
    }

    // MARK: - New Patient Setup

    @Published var patientExists: Bool? = nil
    @Published var patientFirstName: String? = nil

    struct CheckPatientResponse: Decodable {
        let success: Bool
        let exists: Bool?
        let firstName: String?
        let error: String?
    }

    struct SetPasswordResponse: Decodable {
        let success: Bool
        let message: String?
        let error: String?
    }

    func checkPatientExists(email: String) async {
        isLoading = true
        error = nil
        successMessage = nil
        patientExists = nil
        patientFirstName = nil

        do {
            let result: CheckPatientResponse = try await supabase.functions.invoke(
                "patient-set-password",
                options: FunctionInvokeOptions(body: ["email": email])
            )

            if result.exists == true {
                patientExists = true
                patientFirstName = result.firstName
            } else {
                patientExists = false
                error = result.error ?? "No account found. Please ask your clinician to add you."
            }
        } catch {
            self.error = "Unable to check account. Please try again."
            print("Check patient error: \(error)")
        }

        isLoading = false
    }

    func setPatientPassword(email: String, password: String) async {
        isLoading = true
        error = nil
        successMessage = nil

        do {
            let result: SetPasswordResponse = try await supabase.functions.invoke(
                "patient-set-password",
                options: FunctionInvokeOptions(body: ["email": email, "password": password])
            )

            if result.success {
                successMessage = result.message ?? "Password set! You can now sign in."
                // Reset state
                patientExists = nil
                patientFirstName = nil
            } else {
                error = result.error ?? "Failed to set password."
            }
        } catch {
            self.error = "Failed to set password. Please try again."
            print("Set password error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Update Password (after reset link clicked)

    func updatePassword(newPassword: String) async {
        isLoading = true
        error = nil
        successMessage = nil

        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            successMessage = "Password updated successfully!"
        } catch {
            self.error = mapAuthError(error)
            print("Password update error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }

    // MARK: - Error Mapping

    private func mapAuthError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()

        if errorString.contains("invalid login credentials") ||
           errorString.contains("invalid_credentials") {
            return "Invalid email or password. Please try again."
        } else if errorString.contains("email not confirmed") {
            return "Please check your email and confirm your account."
        } else if errorString.contains("user already registered") ||
                  errorString.contains("user_already_exists") {
            return "An account with this email already exists. Try signing in instead."
        } else if errorString.contains("password") && errorString.contains("weak") {
            return "Password is too weak. Use at least 8 characters with mixed case and numbers."
        } else if errorString.contains("rate limit") || errorString.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network error. Please check your connection and try again."
        } else if errorString.contains("invalid email") {
            return "Please enter a valid email address."
        }

        return error.localizedDescription
    }
}
