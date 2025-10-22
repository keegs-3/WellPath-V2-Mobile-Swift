//
//  ContentView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthStateManager()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
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
