//
//  AppIconService.swift
//  WellPath
//
//  Service for fetching app icons from the App Store using bundle identifiers.
//  Used to display source app icons for HealthKit data.
//

import SwiftUI

@MainActor
class AppIconService: ObservableObject {
    static let shared = AppIconService()

    // Cache for app icons (bundle ID -> icon URL)
    private var iconCache: [String: URL] = [:]
    private var loadingBundleIds: Set<String> = []

    private init() {}

    /// Get the icon URL for an app, fetching from App Store if needed
    func getIconURL(bundleId: String) async -> URL? {
        // Check cache first
        if let cached = iconCache[bundleId] {
            return cached
        }

        // Avoid duplicate fetches
        guard !loadingBundleIds.contains(bundleId) else { return nil }
        loadingBundleIds.insert(bundleId)

        defer { loadingBundleIds.remove(bundleId) }

        // Fetch from iTunes API
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)

            if let result = response.results.first,
               let iconURLString = result.artworkUrl100,
               let iconURL = URL(string: iconURLString) {
                iconCache[bundleId] = iconURL
                return iconURL
            }
        } catch {
            print("Failed to fetch app icon for \(bundleId): \(error)")
        }

        return nil
    }

    /// Clear the icon cache
    func clearCache() {
        iconCache.removeAll()
    }
}

// MARK: - iTunes API Response

private struct ITunesLookupResponse: Codable {
    let resultCount: Int
    let results: [ITunesAppResult]
}

private struct ITunesAppResult: Codable {
    let trackName: String?
    let bundleId: String?
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl512: String?
}

// MARK: - SwiftUI View Helper

/// A view that displays an app icon from HealthKit source metadata
struct HealthKitSourceIcon: View {
    let bundleId: String?
    let sourceName: String
    let size: CGFloat

    @State private var iconURL: URL?
    @StateObject private var iconService = AppIconService.shared

    init(bundleId: String?, sourceName: String, size: CGFloat = 24) {
        self.bundleId = bundleId
        self.sourceName = sourceName
        self.size = size
    }

    var body: some View {
        Group {
            if let iconURL = iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                    case .failure:
                        fallbackIcon
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .task {
            if let bundleId = bundleId {
                iconURL = await AppIconService.shared.getIconURL(bundleId: bundleId)
            }
        }
    }

    private var fallbackIcon: some View {
        // Use SF Symbol based on source name
        Image(systemName: iconSymbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(.secondary)
    }

    private var iconSymbol: String {
        let name = sourceName.lowercased()
        if name.contains("watch") || name.contains("apple") {
            return "applewatch"
        } else if name.contains("sleep") || name.contains("bed") {
            return "bed.double.fill"
        } else if name.contains("fitness") || name.contains("workout") {
            return "figure.run"
        } else if name.contains("health") {
            return "heart.fill"
        } else {
            return "app.fill"
        }
    }
}

// MARK: - Source Display Row

/// A reusable row that shows source app icon, name, and optional count
struct HealthKitSourceRow: View {
    let bundleId: String?
    let sourceName: String
    let detail: String?

    init(bundleId: String?, sourceName: String, detail: String? = nil) {
        self.bundleId = bundleId
        self.sourceName = sourceName
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            HealthKitSourceIcon(bundleId: bundleId, sourceName: sourceName, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(sourceName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let detail = detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        HealthKitSourceRow(
            bundleId: "com.eightsleep.EightSleep",
            sourceName: "Eight Sleep",
            detail: "4 samples"
        )

        HealthKitSourceRow(
            bundleId: nil,
            sourceName: "Apple Watch",
            detail: "12 samples"
        )

        HealthKitSourceIcon(
            bundleId: "com.eightsleep.EightSleep",
            sourceName: "Eight Sleep",
            size: 48
        )
    }
    .padding()
}
