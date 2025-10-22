//
//  ProfileView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthStateManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        // Profile Picture Placeholder
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 90, height: 90)

                            Text(viewModel.initials)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(viewModel.fullName)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(viewModel.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Profile Options
                    VStack(spacing: 0) {
                        ProfileOptionRow(icon: "person.fill", title: "Personal Info")
                        Divider().padding(.leading, 60)

                        ProfileOptionRow(icon: "list.clipboard.fill", title: "Questionnaire")
                        Divider().padding(.leading, 60)

                        ProfileOptionRow(icon: "lock.fill", title: "Change Password")
                        Divider().padding(.leading, 60)

                        ProfileOptionRow(icon: "heart.fill", title: "Apple Health Tracking")
                        Divider().padding(.leading, 60)

                        Button(action: {
                            showSignOutAlert = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 44)

                                Text("Sign Out")
                                    .font(.body)
                                    .foregroundColor(.red)

                                Spacer()
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // App Version
                    Text("App Version: 1.0.0 (1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .task {
                await viewModel.loadProfile()
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await viewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 44)

            Text(title)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthStateManager())
}
