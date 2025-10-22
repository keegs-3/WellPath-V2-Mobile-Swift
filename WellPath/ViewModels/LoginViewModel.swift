//
//  LoginViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            try await supabase.auth.signIn(email: email, password: password)
            // Auth state will be handled by AuthStateManager
        } catch {
            self.error = error.localizedDescription
            print("Login error: \(error)")
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
