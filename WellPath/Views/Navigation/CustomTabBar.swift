//
//  CustomTabBar.swift
//  WellPath
//
//  Oura-style custom tab bar with 3 tabs grouped on the left
//  and an isolated FAB (+) on the right.
//
//  Layout: [Score] [Data] [Goals]  |  [+]
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 3 main tabs (grouped)
            HStack(spacing: 0) {
                // Score Tab
                TabBarItem(
                    icon: "heart.circle.fill",
                    label: "Score",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }

                // Data Tab
                TabBarItem(
                    icon: "chart.bar.fill",
                    label: "Data",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }

                // Goals Tab
                TabBarItem(
                    icon: "target",
                    label: "Goals",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            Spacer()

            // Isolated FAB (+)
            Button(action: onAddTap) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.green)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Tab Bar Item

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .green : .secondary)

                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .green : .secondary)
            }
            .frame(width: 70, height: 50)
            .background(
                isSelected ?
                    Color.green.opacity(0.15) :
                    Color.clear
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(0)) {
            print("Add tapped")
        }
    }
}
