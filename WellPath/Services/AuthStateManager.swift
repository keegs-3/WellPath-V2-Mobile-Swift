//
//  AuthStateManager.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class AuthStateManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let supabase = SupabaseManager.shared.client
    private var authStateTask: Task<Void, Never>?

    init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateTask = Task {
            for await (event, session) in await supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    if let session = session {
                        self.isAuthenticated = true
                        self.currentUser = session.user
                        print("User signed in: \(session.user.email ?? "unknown")")
                    }
                case .signedOut:
                    self.isAuthenticated = false
                    self.currentUser = nil
                    print("User signed out")
                case .passwordRecovery:
                    // User clicked password reset link
                    // Keep them authenticated but show password reset UI
                    if let session = session {
                        self.isAuthenticated = false  // Keep on auth screen
                        self.currentUser = session.user
                        print("Password recovery mode for: \(session.user.email ?? "unknown")")
                        // Notify LoginView to show password reset sheet
                        NotificationCenter.default.post(name: .showPasswordReset, object: nil)
                    }
                case .userUpdated:
                    // User updated their profile (including password)
                    if let session = session {
                        self.isAuthenticated = true
                        self.currentUser = session.user
                        print("User updated: \(session.user.email ?? "unknown")")
                    }
                case .tokenRefreshed:
                    // Token was refreshed, keep current state
                    if let session = session {
                        self.currentUser = session.user
                    }
                default:
                    print("Auth event: \(event)")
                    break
                }
            }
        }

        // Check current session
        Task {
            do {
                let session = try await supabase.auth.session
                self.isAuthenticated = true
                self.currentUser = session.user
            } catch {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }
}
