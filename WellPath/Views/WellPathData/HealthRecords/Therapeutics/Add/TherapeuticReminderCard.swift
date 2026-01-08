//
//  TherapeuticReminderCard.swift
//  WellPath
//
//  Tracking and reminder settings for therapeutics.
//  Includes adherence tracking toggle and reminder time pickers.
//

import SwiftUI

struct TherapeuticReminderCard: View {
    @Binding var trackAdherence: Bool
    @Binding var enableReminders: Bool
    @Binding var reminderTimes: [Date]
    let color: Color
    let dosesPerDay: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Tracking & Reminders")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Track adherence toggle
            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(trackAdherence ? color : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Track daily adherence")
                        .font(.subheadline)
                    Text("Log when you take this")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $trackAdherence)
                    .labelsHidden()
                    .tint(color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)

            // Reminders toggle
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundColor(enableReminders ? color : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable reminders")
                        .font(.subheadline)
                    Text("Get notified when it's time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $enableReminders)
                    .labelsHidden()
                    .tint(color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)

            // Reminder times (shown when enabled)
            if enableReminders {
                VStack(spacing: 10) {
                    ForEach(reminderTimes.indices, id: \.self) { index in
                        HStack {
                            Text("Reminder \(index + 1)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $reminderTimes[index],
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()

                            if reminderTimes.count > 1 {
                                Button {
                                    withAnimation {
                                        reminderTimes.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }

                    // Add reminder button (up to 4 or dosesPerDay)
                    let maxReminders = max(4, dosesPerDay)
                    if reminderTimes.count < maxReminders {
                        Button {
                            withAnimation {
                                // Default to 8 AM, then add 6 hours for each subsequent
                                let baseHour = 8
                                let offset = reminderTimes.count * 6
                                let hour = (baseHour + offset) % 24
                                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                components.hour = hour
                                components.minute = 0
                                let newTime = Calendar.current.date(from: components) ?? Date()
                                reminderTimes.append(newTime)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(color)
                                Text("Add reminder time")
                                    .foregroundColor(color)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(color.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: enableReminders)
        .onChange(of: enableReminders) { _, enabled in
            if enabled && reminderTimes.isEmpty {
                // Add a default 8 AM reminder
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 8
                components.minute = 0
                if let defaultTime = Calendar.current.date(from: components) {
                    reminderTimes = [defaultTime]
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TherapeuticReminderCard(
            trackAdherence: .constant(true),
            enableReminders: .constant(false),
            reminderTimes: .constant([]),
            color: .green,
            dosesPerDay: 1
        )

        TherapeuticReminderCard(
            trackAdherence: .constant(true),
            enableReminders: .constant(true),
            reminderTimes: .constant([
                Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
            ]),
            color: .purple,
            dosesPerDay: 2
        )
    }
    .padding()
}
