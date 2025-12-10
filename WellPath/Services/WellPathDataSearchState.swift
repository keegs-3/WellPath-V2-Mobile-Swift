//
//  WellPathDataSearchState.swift
//  WellPath
//
//  Shared search state for WellPath Data navigation
//  Persists search mode across navigation hierarchy
//

import SwiftUI

@MainActor
class WellPathDataSearchState: ObservableObject {
    static let shared = WellPathDataSearchState()

    /// Whether search mode is active
    @Published var isSearchActive = false

    /// The current search text
    @Published var searchText = ""

    /// Whether the search field is focused
    @Published var isSearchFocused = false

    private init() {}

    /// Activate search mode
    func activateSearch() {
        withAnimation {
            isSearchActive = true
        }
    }

    /// Deactivate search mode and clear search
    func deactivateSearch() {
        withAnimation {
            isSearchActive = false
            searchText = ""
            isSearchFocused = false
        }
    }

    /// Clear search text without deactivating search mode
    func clearSearchText() {
        searchText = ""
    }
}
