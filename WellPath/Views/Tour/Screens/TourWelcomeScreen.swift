//
//  TourWelcomeScreen.swift
//  WellPath
//
//  Welcome/intro screens (steps 1-2): Black screen with Chiron avatar
//

import SwiftUI

struct TourWelcomeScreen: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Spacer()

            // Chiron illustration - large and centered
            // Coach bubble has the message, so just show the visual
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                ChironAvatar(size: .hero, style: .gradient, animate: true)
            }

            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    TourWelcomeScreen()
}
