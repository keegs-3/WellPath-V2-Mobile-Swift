//
//  PeriodNavigationView.swift
//  WellPath
//
//  Period navigation with arrows and calendar picker
//  Supports Day/Week/Month/6Month/Year views
//

import SwiftUI

struct PeriodNavigationView: View {
    let selectedPeriod: TimePeriod
    @Binding var currentDate: Date
    @State private var showingDatePicker = false

    var body: some View {
        HStack(spacing: 16) {
            // Previous button
            Button(action: moveToPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Date display
            Button(action: { showingDatePicker = true }) {
                HStack(spacing: 8) {
                    Text(dateRangeText)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)

            // Next button
            Button(action: moveToNext) {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack(spacing: 16) {
                    // Add helpful hint for month/6M/year selection
                    if selectedPeriod == .month {
                        Text("Select any day in the month")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    } else if selectedPeriod == .sixMonth {
                        Text("Select any day in the 6-month period")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    } else if selectedPeriod == .year {
                        Text("Select any day in the year")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }

                    // Use different picker styles based on period
                    Group {
                        if selectedPeriod == .day || selectedPeriod == .week {
                            DatePicker(
                                "Select Date",
                                selection: $currentDate,
                                displayedComponents: datePickerComponents
                            )
                            .datePickerStyle(.graphical)
                        } else {
                            DatePicker(
                                "Select Date",
                                selection: $currentDate,
                                displayedComponents: datePickerComponents
                            )
                            .datePickerStyle(.wheel)
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationTitle(pickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var pickerTitle: String {
        switch selectedPeriod {
        case .day:
            return "Select Day"
        case .week:
            return "Select Week"
        case .month:
            return "Select Month"
        case .sixMonth:
            return "Select 6-Month Period"
        case .year:
            return "Select Year"
        }
    }

    private var dateRangeText: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: currentDate)

        case .week:
            // Get Monday-Sunday of the week
            let weekday = calendar.component(.weekday, from: currentDate)
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)

            guard let monday = calendar.date(byAdding: .day, value: daysFromMonday, to: currentDate),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
                return "Week"
            }

            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: monday)

            // Check if week spans two months
            if calendar.component(.month, from: monday) == calendar.component(.month, from: sunday) {
                formatter.dateFormat = "d, yyyy"
                return "\(startStr)-\(formatter.string(from: sunday))"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                return "\(startStr) - \(formatter.string(from: sunday))"
            }

        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDate)

        case .sixMonth:
            let startOfPeriod = calendar.date(from: calendar.dateComponents([.year], from: currentDate))!
            let monthComponent = calendar.component(.month, from: currentDate)
            let periodStart = monthComponent <= 6 ? startOfPeriod : calendar.date(byAdding: .month, value: 6, to: startOfPeriod)!

            formatter.dateFormat = "MMM"
            let startMonth = formatter.string(from: periodStart)

            guard let endDate = calendar.date(byAdding: .month, value: 5, to: periodStart) else {
                return "6 Months"
            }
            let endMonth = formatter.string(from: endDate)
            formatter.dateFormat = "yyyy"
            let year = formatter.string(from: periodStart)

            return "\(startMonth)-\(endMonth) \(year)"

        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentDate)
        }
    }

    private var datePickerComponents: DatePickerComponents {
        switch selectedPeriod {
        case .day, .week:
            return [.date]  // Full date picker
        case .month, .sixMonth, .year:
            return [.date]  // Date components (wheel shows month/year)
        }
    }

    private func moveToPrevious() {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        case .week:
            currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .month:
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        case .sixMonth:
            currentDate = calendar.date(byAdding: .month, value: -6, to: currentDate) ?? currentDate
        case .year:
            currentDate = calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate
        }
    }

    private func moveToNext() {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        case .week:
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .month:
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        case .sixMonth:
            currentDate = calendar.date(byAdding: .month, value: 6, to: currentDate) ?? currentDate
        case .year:
            currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PeriodNavigationView(
            selectedPeriod: .day,
            currentDate: .constant(Date())
        )

        PeriodNavigationView(
            selectedPeriod: .week,
            currentDate: .constant(Date())
        )

        PeriodNavigationView(
            selectedPeriod: .month,
            currentDate: .constant(Date())
        )
    }
    .padding()
}
