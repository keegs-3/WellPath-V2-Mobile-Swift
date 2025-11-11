//
//  HealthKitAuthorizationView.swift
//  WellPath
//
//  View for requesting HealthKit authorization
//

import SwiftUI
import HealthKit

struct HealthKitAuthorizationView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isRequesting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Connect to Apple Health")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("WellPath uses your health data to provide personalized insights and track your progress.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Status indicator
            statusSection

            // Data types we'll access
            VStack(alignment: .leading, spacing: 16) {
                Text("We'll access:")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    DataTypeRow(icon: "bed.double.fill", title: "Sleep Data", description: "Track your sleep patterns and quality")
                    DataTypeRow(icon: "figure.walk", title: "Activity & Exercise", description: "Steps, workouts, and active energy")
                    DataTypeRow(icon: "heart.fill", title: "Heart Health", description: "Heart rate and variability")
                    DataTypeRow(icon: "fork.knife", title: "Nutrition", description: "Water, protein, and calorie intake")
                    DataTypeRow(icon: "figure.mind.and.body", title: "Mindfulness", description: "Meditation and breathing sessions")
                    DataTypeRow(icon: "figure.arms.open", title: "Body Measurements", description: "Weight, height, and BMI")
                }
            }
            .padding(.vertical)

            Spacer()

            // Authorization button
            if healthKitManager.authorizationStatus == .notAvailable {
                Text("HealthKit is not available on this device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    Task {
                        await requestAuthorization()
                    }
                }) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(buttonText)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRequesting || healthKitManager.authorizationStatus == .authorized)
                .padding(.horizontal)
            }

            // Privacy note
            Text("Your health data is private and never leaves your device without your permission.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)

            // Test HealthKit Connection button
            if healthKitManager.authorizationStatus == .authorized {
                VStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await createTestSleepData()
                        }
                    }) {
                        Text("Create Test Sleep Data (Last 7 Days)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Button(action: {
                        Task {
                            await testHealthKitConnection()
                        }
                    }) {
                        Text("Test HealthKit Connection")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom)
            }
        }
        .alert("Authorization Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(statusColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var statusIcon: String {
        switch healthKitManager.authorizationStatus {
        case .notDetermined:
            return "questionmark.circle.fill"
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notAvailable:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch healthKitManager.authorizationStatus {
        case .notDetermined:
            return .orange
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notAvailable:
            return .gray
        }
    }

    private var statusText: String {
        switch healthKitManager.authorizationStatus {
        case .notDetermined:
            return "Authorization not yet requested"
        case .authorized:
            return "Connected to Apple Health"
        case .denied:
            return "Authorization denied - Enable in Settings"
        case .notAvailable:
            return "HealthKit not available"
        }
    }

    private var buttonText: String {
        switch healthKitManager.authorizationStatus {
        case .notDetermined:
            return "Connect to Apple Health"
        case .authorized:
            return "Already Connected"
        case .denied:
            return "Open Settings"
        case .notAvailable:
            return "Not Available"
        }
    }

    private var buttonColor: Color {
        switch healthKitManager.authorizationStatus {
        case .notDetermined:
            return .blue
        case .authorized:
            return .green
        case .denied:
            return .orange
        case .notAvailable:
            return .gray
        }
    }

    // MARK: - Actions

    private func createTestSleepData() async {
        print("📝 Creating test sleep data...")

        do {
            try await healthKitManager.saveTestSleepData()
            print("✅ Test sleep data created successfully!")
        } catch {
            print("❌ Failed to create test sleep data: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func testHealthKitConnection() async {
        print("🧪 Testing HealthKit connection...")

        do {
            // Try to fetch sleep data from the last 7 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

            let sleepData = try await healthKitManager.fetchSleepData(from: startDate, to: endDate)
            print("✅ HealthKit connection working! Fetched \(sleepData.count) sleep samples")

            if sleepData.isEmpty {
                print("ℹ️ No sleep data available in HealthKit (this is normal if you haven't added any)")
            } else {
                for sample in sleepData.prefix(3) {
                    print("  - Sleep sample: \(sample.startDate) to \(sample.endDate)")
                }
            }

            // Also check step count
            let steps = try await healthKitManager.fetchStepCount(from: startDate, to: endDate)
            print("✅ Step count for last 7 days: \(steps)")

        } catch {
            print("❌ HealthKit connection test failed: \(error)")
        }
    }

    private func requestAuthorization() async {
        if healthKitManager.authorizationStatus == .denied {
            // Open Settings app
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }

        isRequesting = true

        do {
            try await healthKitManager.requestAuthorization()
            print("✅ HealthKit authorization successful")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ HealthKit authorization failed: \(error)")
        }

        isRequesting = false
    }
}

// MARK: - Data Type Row

struct DataTypeRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthKitAuthorizationView()
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
    }
}
