//
//  WellPathDataSearchBar.swift
//  WellPath
//
//  Persistent floating search bar for WellPath Data navigation
//  Shows above tab bar when search mode is active
//  Uses iOS 26 liquid glass styling when available
//

import SwiftUI

struct WellPathDataSearchBar: View {
    @ObservedObject var searchState: WellPathDataSearchState
    @FocusState.Binding var isFocused: Bool
    let placeholder: String

    // Match height for both search bar and X button
    private let barHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            // Search bar with speech button
            searchBarContent
                .padding(.horizontal, 16)
                .frame(height: barHeight)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .modifier(GlassEffectModifier())

            // X button to close search mode - liquid glass style, same height as search bar
            Button {
                isFocused = false
                searchState.deactivateSearch()
            } label: {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: barHeight, height: barHeight)
                .modifier(GlassEffectModifier())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var searchBarContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            TextField(placeholder, text: $searchState.searchText)
                .font(.body)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.search)

            // Clear text button (inside search bar)
            if !searchState.searchText.isEmpty {
                Button {
                    searchState.clearSearchText()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }

            // Speech/microphone button
            Button {
                // TODO: Implement speech-to-text
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Glass Effect Modifier (iOS 26+)

struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content
        }
    }
}
