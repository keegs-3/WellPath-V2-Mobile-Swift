//
//  SideMenuView.swift
//  WellPath
//
//  Oura-style side menu that slides in from the left (80% width)
//  Contains: Profile, Journey Status, Learn, Chat, Settings, Sign Out
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var authManager: AuthStateManager
    @StateObject private var profileViewModel = ProfileViewModel()
    @ObservedObject private var journeyState = JourneyStateService.shared
    @Binding var isShowing: Bool
    @Binding var showEducation: Bool
    @Binding var showCoachChat: Bool
    @Binding var showOnboarding: Bool
    @Binding var showTour: Bool

    @State private var showSignOutAlert = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Menu content (80% width)
                VStack(alignment: .leading, spacing: 0) {
                    // Close button row
                    HStack {
                        Spacer()
                        Button {
                            closeMenu()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 8)

                    // Profile Header
                    profileHeader
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Journey Status Card (shows onboarding progress or cycle status)
                    if journeyState.shouldShowStatusCard {
                        JourneyStatusCard(
                            state: journeyState.state,
                            onContinue: {
                                showOnboarding = true
                                closeMenu()
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Menu Items
                    ScrollView {
                        VStack(spacing: 4) {
                            // Learn
                            SideMenuItem(
                                icon: "book.fill",
                                title: "Learn",
                                color: .blue
                            ) {
                                showEducation = true
                                closeMenu()
                            }

                            // Chat with Coach
                            SideMenuItem(
                                icon: "bubble.left.and.bubble.right.fill",
                                title: "Chat with Coach",
                                color: .green
                            ) {
                                showCoachChat = true
                                closeMenu()
                            }

                            Divider()
                                .padding(.vertical, 12)
                                .padding(.horizontal)

                            // Settings Section
                            Text("SETTINGS")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)

                            // Personal Info
                            SideMenuNavItem(
                                icon: "person.fill",
                                title: "Personal Info",
                                destination: PersonalInfoView()
                            ) {
                                closeMenu()
                            }

                            // Unit Preferences
                            SideMenuNavItem(
                                icon: "ruler.fill",
                                title: "Unit Preferences",
                                destination: UnitPreferencesView()
                            ) {
                                closeMenu()
                            }

                            // Apple Health
                            SideMenuNavItem(
                                icon: "heart.fill",
                                title: "Apple Health",
                                destination: HealthKitAuthorizationView()
                            ) {
                                closeMenu()
                            }

                            // Replay Tour
                            SideMenuItem(
                                icon: "sparkles",
                                title: "Replay Tour",
                                color: .purple
                            ) {
                                // Close menu first, then show tour after animation completes
                                closeMenu()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showTour = true
                                }
                            }

                            Divider()
                                .padding(.vertical, 12)
                                .padding(.horizontal)

                            // Sign Out
                            SideMenuItem(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                color: .red
                            ) {
                                showSignOutAlert = true
                            }
                        }
                        .padding(.vertical, 16)
                    }

                    Spacer()

                    // App Version
                    Text("WellPath v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                }
                .frame(width: geometry.size.width * 0.80)
                .background(Color(uiColor: .systemBackground))

                // Tap area to dismiss (20% on right)
                Color.black.opacity(0.3)
                    .frame(width: geometry.size.width * 0.20)
                    .onTapGesture {
                        closeMenu()
                    }
            }
        }
        .ignoresSafeArea()
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await profileViewModel.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await profileViewModel.loadProfile()
            await journeyState.loadState()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 64, height: 64)

                Text(profileViewModel.initials)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
            }

            // Name & Email
            if profileViewModel.isLoading {
                ProgressView()
            } else {
                Text(profileViewModel.fullName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(profileViewModel.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isShowing = false
        }
    }
}

// MARK: - Side Menu Item (Button Action)

struct SideMenuItem: View {
    let icon: String
    let title: String
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .foregroundColor(color == .red ? .red : .primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Side Menu Nav Item (NavigationLink)

struct SideMenuNavItem<Destination: View>: View {
    let icon: String
    let title: String
    let destination: Destination
    let onTap: () -> Void

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { _ in
            onTap()
        })
    }
}

#Preview {
    SideMenuView(
        isShowing: .constant(true),
        showEducation: .constant(false),
        showCoachChat: .constant(false),
        showOnboarding: .constant(false),
        showTour: .constant(false)
    )
    .environmentObject(AuthStateManager())
}
