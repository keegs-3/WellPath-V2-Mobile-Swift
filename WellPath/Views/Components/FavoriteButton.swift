//
//  FavoriteButton.swift
//  WellPath
//
//  Reusable favorite/pin button for toolbar
//  Now includes card_id and section_id for proper display config lookup
//

import SwiftUI

/// Size variants for FavoriteButton
enum FavoriteButtonSize {
    case compact   // For inline use on cards (14pt, muted inactive)
    case regular   // For toolbar use (18pt, primary inactive)

    var fontSize: CGFloat {
        switch self {
        case .compact: return 14
        case .regular: return 18
        }
    }

    var inactiveColor: Color {
        switch self {
        case .compact: return .secondary.opacity(0.5)
        case .regular: return .primary
        }
    }
}

struct FavoriteButton: View {
    let itemType: FavoriteItemType
    let itemId: String
    let displayName: String
    let pillar: String
    let cardId: String?      // Links to display_view_cards for routing
    let sectionId: String?   // Links to display_category_sections for color/icon
    let size: FavoriteButtonSize

    @ObservedObject private var favoritesService = FavoritesService.shared
    @State private var isToggling = false

    init(
        itemType: FavoriteItemType,
        itemId: String,
        displayName: String,
        pillar: String,
        cardId: String? = nil,
        sectionId: String? = nil,
        size: FavoriteButtonSize = .regular
    ) {
        self.itemType = itemType
        self.itemId = itemId
        self.displayName = displayName
        self.pillar = pillar
        self.cardId = cardId
        self.sectionId = sectionId
        self.size = size
    }

    private var isFavorite: Bool {
        favoritesService.isFavorite(type: itemType, id: itemId)
    }

    var body: some View {
        Button {
            guard !isToggling else { return }
            isToggling = true

            Task {
                await favoritesService.toggleFavorite(
                    type: itemType,
                    id: itemId,
                    displayName: displayName,
                    pillar: pillar,
                    cardId: cardId,
                    sectionId: sectionId
                )
                isToggling = false
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : size.inactiveColor)
                .font(.system(size: size.fontSize))
                .scaleEffect(isToggling ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isToggling)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isToggling)
    }
}

// MARK: - View Extension for easy toolbar addition

extension View {
    /// Add a favorite button to the toolbar (with full display config support)
    func favoriteToolbar(
        itemType: FavoriteItemType,
        itemId: String,
        displayName: String,
        pillar: String,
        cardId: String? = nil,
        sectionId: String? = nil
    ) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: itemType,
                    itemId: itemId,
                    displayName: displayName,
                    pillar: pillar,
                    cardId: cardId,
                    sectionId: sectionId
                )
            }
        }
    }
}

// MARK: - Detail View Toolbar Modifier

/// Configuration for detail view toolbar buttons
struct DetailToolbarConfig {
    let metricId: String
    let displayName: String
    let pillar: String
    let cardId: String?
    let sectionId: String?
    let itemType: FavoriteItemType

    init(
        metricId: String,
        displayName: String,
        pillar: String,
        cardId: String? = nil,
        sectionId: String? = nil,
        itemType: FavoriteItemType = .metric
    ) {
        self.metricId = metricId
        self.displayName = displayName
        self.pillar = pillar
        self.cardId = cardId
        self.sectionId = sectionId
        self.itemType = itemType
    }
}

/// ViewModifier that adds favorite, entry, and data management buttons to toolbar
struct DetailViewToolbar<EntryContent: View, DataManagementContent: View>: ViewModifier {
    let config: DetailToolbarConfig
    let entryView: EntryContent?
    let dataManagementView: DataManagementContent?

    @Binding var showEntry: Bool
    @Binding var showDataManagement: Bool

    init(
        config: DetailToolbarConfig,
        showEntry: Binding<Bool>,
        showDataManagement: Binding<Bool>,
        @ViewBuilder entryView: () -> EntryContent?,
        @ViewBuilder dataManagementView: () -> DataManagementContent?
    ) {
        self.config = config
        self._showEntry = showEntry
        self._showDataManagement = showDataManagement
        self.entryView = entryView()
        self.dataManagementView = dataManagementView()
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Leading: Data Management
                if dataManagementView != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showDataManagement = true
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }

                // Trailing: Favorite + Entry (favorite first, then +)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    FavoriteButton(
                        itemType: config.itemType,
                        itemId: config.metricId,
                        displayName: config.displayName,
                        pillar: config.pillar,
                        cardId: config.cardId,
                        sectionId: config.sectionId
                    )

                    if entryView != nil {
                        Button {
                            showEntry = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEntry) {
                if let entryView = entryView {
                    entryView
                }
            }
            .sheet(isPresented: $showDataManagement) {
                if let dataManagementView = dataManagementView {
                    dataManagementView
                }
            }
    }
}

extension View {
    /// Add full detail view toolbar with favorite, entry, and data management buttons
    func detailViewToolbar<EntryContent: View, DataManagementContent: View>(
        config: DetailToolbarConfig,
        showEntry: Binding<Bool>,
        showDataManagement: Binding<Bool>,
        @ViewBuilder entryView: () -> EntryContent?,
        @ViewBuilder dataManagementView: () -> DataManagementContent?
    ) -> some View {
        modifier(DetailViewToolbar(
            config: config,
            showEntry: showEntry,
            showDataManagement: showDataManagement,
            entryView: entryView,
            dataManagementView: dataManagementView
        ))
    }

    /// Add favorite-only toolbar (for views that already handle entry/data management separately)
    func favoriteOnlyToolbar(config: DetailToolbarConfig) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: config.itemType,
                    itemId: config.metricId,
                    displayName: config.displayName,
                    pillar: config.pillar,
                    cardId: config.cardId,
                    sectionId: config.sectionId
                )
            }
        }
    }
}
