//
//  TourWrapUpScreen.swift
//  WellPath
//
//  Final tour screen: Summary and CTA to start setup
//

import SwiftUI

struct TourWrapUpScreen: View {
    let onStartSetup: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success illustration
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }

            VStack(spacing: 12) {
                Text("Ready to Begin!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Complete your health profile and your clinician will create personalized goals based on your unique data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // CTA Button
            Button(action: onStartSetup) {
                HStack {
                    Text("Complete Setup")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    TourWrapUpScreen(onStartSetup: {})
}
