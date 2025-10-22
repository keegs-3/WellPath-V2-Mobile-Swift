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
                default:
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
