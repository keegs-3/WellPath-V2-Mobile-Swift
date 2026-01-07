//
//  LiquidGlassTabBar.swift
//  WellPath
//
//  iOS 26 Liquid Glass two-bubble tab bar
//  Left bubble: grouped tab icons (Today | Score | My Data)
//  Right bubble: + button
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Left bubble: Tab icons
            tabsBubble

            // Right bubble: + button
            addButtonBubble
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Tabs Bubble

    private var tabsBubble: some View {
        HStack(spacing: 0) {
            // Goals
            TabBarIcon(
                icon: "sun.max",
                label: "Goals",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                }
            }

            // Score
            TabBarIcon(
                icon: "gauge.with.needle",
                label: "Score",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            }

            // My Data
            TabBarIcon(
                icon: "list.clipboard",
                label: "My Data",
                isSelected: selectedTab == 2
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 2
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(tabBarBackground)
    }

    // MARK: - Add Button Bubble

    private var addButtonBubble: some View {
        Button(action: onAddTap) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: 66, height: 66)
        }
        .background(glassBackground(cornerRadius: 22))
    }

    // MARK: - Glass Background

    @ViewBuilder
    private func glassBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.clear)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        glassBackground(cornerRadius: 25)
    }
}

// MARK: - Tab Bar Icon

struct TabBarIcon: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .fontWeight(isSelected ? .semibold : .regular)

                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.green : Color.secondary)
            .frame(width: 70, height: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            LiquidGlassTabBar(
                selectedTab: .constant(0),
                onAddTap: { print("Add tapped") }
            )
        }
    }
}
