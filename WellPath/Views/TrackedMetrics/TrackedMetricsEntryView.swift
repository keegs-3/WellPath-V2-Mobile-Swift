//
//  TrackedMetricsEntryView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct TrackedMetricsEntryView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Sleep") {
                    NavigationLink("Log Sleep") {
                        SleepEntryView()
                    }
                }

                Section("Exercise") {
                    NavigationLink("Log Cardio") {
                        Text("Cardio Entry")
                    }
                    NavigationLink("Log Strength") {
                        Text("Strength Entry")
                    }
                }

                Section("Nutrition") {
                    NavigationLink("Log Protein") {
                        Text("Protein Entry - TODO")
                    }
                    NavigationLink("Log Meal") {
                        Text("Meal Entry")
                    }
                    NavigationLink("Log Water") {
                        Text("Water Entry")
                    }
                }
            }
            .navigationTitle("Track Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TrackedMetricsEntryView()
}
