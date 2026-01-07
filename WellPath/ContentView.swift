//
//  ContentView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthStateManager()

    // First launch flow state
    @State private var showFirstLaunch = false
    @State private var showWizardFromFirstLaunch = false
    @State private var showTourFromFirstLaunch = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
                    .fullScreenCover(isPresented: $showFirstLaunch) {
                        FirstLaunchView(
                            showWizard: $showWizardFromFirstLaunch,
                            startTour: $showTourFromFirstLaunch
                        )
                    }
                    .fullScreenCover(isPresented: $showWizardFromFirstLaunch) {
                        WizardView()
                    }
                    .fullScreenCover(isPresented: $showTourFromFirstLaunch) {
                        TourContainerView()
                    }
                    .onAppear {
                        // Show first launch modal if user hasn't completed it
                        if !FirstLaunchView.hasCompletedFirstLaunch {
                            // Small delay to let main view load first
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showFirstLaunch = true
                            }
                        }
                    }
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
