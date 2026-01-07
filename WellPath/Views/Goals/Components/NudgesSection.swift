//
//  NudgesSection.swift
//  WellPath
//
//  Displays recent coach nudges/messages on the Goals tab
//

import SwiftUI

struct NudgesSection: View {
    let nudges: [CoachNudge]
    var onNudgeTap: ((CoachNudge) -> Void)?
    var onViewAllTap: (() -> Void)?

    private var unreadCount: Int {
        nudges.filter { !$0.isRead }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ChironAvatar(size: .small, style: .filled)

                Text("Chiron")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if unreadCount > 0 {
                    Text("\(unreadCount) new")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(8)
                }

                Spacer()

                if nudges.count > 2 {
                    Button {
                        onViewAllTap?()
                    } label: {
                        HStack(spacing: 2) {
                            Text("View all")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            if nudges.isEmpty {
                // Empty state
                HStack(spacing: 12) {
                    ChironAvatar(size: .medium, style: .outlined)

                    Text("No messages yet. Chiron will send you tips and encouragement as you work toward your goals.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                // Nudge cards
                VStack(spacing: 8) {
                    ForEach(nudges.prefix(3)) { nudge in
                        NudgeCard(nudge: nudge)
                            .onTapGesture {
                                onNudgeTap?(nudge)
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Nudge Card

struct NudgeCard: View {
    let nudge: CoachNudge

    private var toneIcon: String {
        switch nudge.tone {
        case "celebratory": return "party.popper.fill"
        case "educational": return "lightbulb.fill"
        case "motivational": return "flame.fill"
        case "supportive": return "heart.fill"
        default: return "bubble.left.fill"
        }
    }

    private var toneColor: Color {
        switch nudge.tone {
        case "celebratory": return .yellow
        case "educational": return .blue
        case "motivational": return .orange
        case "supportive": return .pink
        default: return .green
        }
    }

    private var timeAgo: String {
        guard let date = ISO8601DateFormatter().date(from: nudge.createdAt) else {
            return ""
        }

        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(toneColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: toneIcon)
                    .font(.system(size: 14))
                    .foregroundColor(toneColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !nudge.isRead {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }

                    Text(nudge.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(nudge.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(nudge.isRead ? Color.clear : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Full Nudge History View

struct NudgesHistoryView: View {
    let nudges: [CoachNudge]
    var onNudgeTap: ((CoachNudge) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(nudges) { nudge in
                    NudgeCard(nudge: nudge)
                        .onTapGesture {
                            onNudgeTap?(nudge)
                        }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Coach Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            NudgesSection(
                nudges: [
                    CoachNudge.mock(title: "Great progress!", message: "You're 85% to your protein goal today. Keep it up!", tone: "celebratory", isRead: false),
                    CoachNudge.mock(title: "Tip", message: "Try adding Greek yogurt to your breakfast - it's packed with protein!", tone: "educational", isRead: true),
                    CoachNudge.mock(title: "You got this!", message: "Just 2,000 more steps to hit your daily target.", tone: "motivational", isRead: true),
                ],
                onNudgeTap: { _ in },
                onViewAllTap: { }
            )

            NudgesSection(
                nudges: [],
                onNudgeTap: { _ in },
                onViewAllTap: { }
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

// MARK: - Mock Helper

#if DEBUG
extension CoachNudge {
    static func mock(title: String, message: String, tone: String, isRead: Bool) -> CoachNudge {
        let readAt = isRead ? "2025-01-15T12:00:00Z" : nil
        let json = """
        {
            "nudge_id": "\(UUID().uuidString)",
            "patient_id": "patient-1",
            "title": "\(title)",
            "message": "\(message)",
            "tone": "\(tone)",
            "created_at": "2025-01-15T10:30:00Z"\(readAt != nil ? ",\"read_at\": \"\(readAt!)\"" : "")
        }
        """
        return try! JSONDecoder().decode(CoachNudge.self, from: json.data(using: .utf8)!)
    }
}
#endif
